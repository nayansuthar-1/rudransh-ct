import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// Notices the office posts (IMPLEMENTATION_PLAN Phase 14).
///
/// One page for every role: admins get the New button and can delete, agents
/// and members read. The database decides which notices each role is shown.
class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider);
    final isAdmin = ref.watch(currentUserProvider).isAdmin;
    final items = async.value;

    return PageBody(
      maxWidth: 860,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: S.announcements,
                subtitle: S.announcementsSub,
              ),
            ),
            if (isAdmin)
              FilledButton.icon(
                onPressed: () => showAnnouncementDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(S.newAnnouncement),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        if (items == null && async.hasError)
          AppCard(
            child: ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(announcementsProvider),
            ),
          )
        else if (items == null)
          const AppCard(child: LoadingState())
        else if (items.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.campaign_outlined,
              message: isAdmin ? S.noAnnouncementsHint : S.noAnnouncements,
            ),
          )
        else
          for (final a in items) ...[
            _AnnouncementCard(a, canDelete: isAdmin),
            const SizedBox(height: Space.md),
          ],
      ],
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard(this.item, {required this.canDelete});

  final Announcement item;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                item.isForEveryone ? S.forEveryYojna : item.yojnaName,
                tone: item.isForEveryone ? PillTone.info : PillTone.brand,
              ),
              if (canDelete)
                IconButton(
                  tooltip: S.delete,
                  onPressed: () => _confirmDelete(context, ref),
                  icon: Icon(Icons.delete_outline, size: 18, color: c.danger),
                ),
            ],
          ),
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(item.body, style: text.bodyMedium),
          ],
          const SizedBox(height: Space.sm),
          Text(
            Fmt.date(item.publishedAt),
            style: text.labelSmall?.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(S.delete),
        content: Text('Delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(announcementsProvider.notifier).remove(item.id);
  }
}

/// Admin-only compose box.
Future<void> showAnnouncementDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _AnnouncementDialog(),
    );

class _AnnouncementDialog extends ConsumerStatefulWidget {
  const _AnnouncementDialog();

  @override
  ConsumerState<_AnnouncementDialog> createState() =>
      _AnnouncementDialogState();
}

class _AnnouncementDialogState extends ConsumerState<_AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  /// Null means every Yojna.
  String? _yojnaId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(announcementsProvider.notifier).post(
            title: _title.text,
            body: _body.text,
            yojnaId: _yojnaId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];

    return AppDialog(
      title: S.newAnnouncement,
      maxWidth: 520,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const ButtonSpinner() : const Text(S.post),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: S.announcementTitle,
              controller: _title,
              required: true,
              autofocus: true,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Give the announcement a title.'
                  : null,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.announcementBody,
              controller: _body,
              maxLines: 4,
            ),
            const SizedBox(height: Space.md),
            AppDropdown<Yojna>(
              label: S.yojna,
              value: yojnas.where((y) => y.id == _yojnaId).firstOrNull,
              items: yojnas,
              itemLabel: (y) => y.name,
              includeAllOption: true,
              allLabel: S.forEveryYojna,
              onChanged: (y) => setState(() => _yojnaId = y?.id),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(
                _error!,
                style: TextStyle(color: context.colors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
