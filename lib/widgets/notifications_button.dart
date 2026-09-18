import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import '../state/providers.dart';
import 'primitives.dart';

/// Bell with the unread count, for every role (IMPLEMENTATION_PLAN Phase 14).
///
/// Sits beside the admin-only Requests button: that one is a work queue, this
/// one is what the office did with work already sent in.
class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unread = ref.watch(unreadCountProvider);

    return IconButton(
      tooltip: unread == 0 ? S.notifications : '${S.notifications} ($unread)',
      onPressed: () => showNotificationsPanel(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 19),
          if (unread > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                constraints: const BoxConstraints(minWidth: 13),
                height: 13,
                decoration: BoxDecoration(
                  color: c.danger,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: c.surface, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: TextStyle(
                      color: c.onBrand,
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The panel itself. A dialog rather than an anchored menu, so it behaves the
/// same on a phone and on a desktop.
Future<void> showNotificationsPanel(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _NotificationsDialog(),
    );

class _NotificationsDialog extends ConsumerWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.lg, Space.lg, Space.sm, Space.sm),
              child: Row(
                children: [
                  // Expanded, not a Spacer: the two buttons beside it need
                  // the room first on a narrow phone.
                  Expanded(
                    child: Text(
                      S.notifications,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (unread > 0)
                    TextButton(
                      onPressed: () => ref
                          .read(notificationsProvider.notifier)
                          .markAllRead(),
                      child: const Text(S.markAllRead),
                    ),
                  IconButton(
                    tooltip: S.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(
              child: switch (async) {
                AsyncError(:final error) => ErrorStateView(error: error),
                AsyncLoading() => const LoadingState(),
                _ => _list(context, ref, async.value ?? const []),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.xl),
        child: EmptyState(
          icon: Icons.notifications_none_rounded,
          message: S.noNotificationsHint,
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.colors.border),
      itemBuilder: (_, i) => _NotificationTile(items[i]),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.item);

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final dot = item.kind.isBad
        ? c.danger
        : (item.kind.isGood ? c.success : c.info);

    return InkWell(
      onTap: () async {
        if (item.isUnread) {
          await ref.read(notificationsProvider.notifier).markRead(item.id);
        }
        if (!context.mounted) return;
        if (item.link.isEmpty) return;
        Navigator.of(context).pop();
        context.go(item.link);
      },
      child: Container(
        color: item.isUnread ? c.brandSoft.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: item.isUnread ? dot : c.borderStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight:
                          item.isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _ago(item.createdAt),
                    style: text.labelSmall?.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Short relative time; the exact stamp is rarely what anyone wants here.
  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}
