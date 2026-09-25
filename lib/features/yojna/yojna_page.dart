import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/forms/yojna_form_dialog.dart';
import '../../widgets/primitives.dart';

class YojnaPage extends ConsumerWidget {
  const YojnaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(yojnaListProvider);
    final yojnas = async.value ?? const <Yojna>[];
    final counts =
        ref.watch(membersPerYojnaProvider).value ?? const <String, int>{};

    return PageBody(
      children: [
        SectionHeader(
          title: S.yojna,
          subtitle: S.yojnaSub,
          actions: [
            FilledButton.icon(
              onPressed: () => showYojnaFormDialog(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('New Yojna'),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        if (async.isLoading && async.value == null)
          const LoadingState()
        else if (async.hasError && async.value == null)
          ErrorStateView(
            error: async.error!,
            onRetry: () => ref.invalidate(yojnaListProvider),
          )
        else if (yojnas.isEmpty)
          AppCard(
            child: EmptyState(
              message: 'No Yojna has been created yet',
              icon: Icons.workspaces_outline,
              action: FilledButton.icon(
                onPressed: () => showYojnaFormDialog(context),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Create Yojna'),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final columns =
                  (constraints.maxWidth / 340).floor().clamp(1, 3);
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final y in yojnas)
                    SizedBox(
                      width: width,
                      child: _YojnaCard(
                        yojna: y,
                        memberCount: counts[y.id] ?? 0,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _YojnaCard extends ConsumerWidget {
  const _YojnaCard({required this.yojna, required this.memberCount});

  final Yojna yojna;
  final int memberCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          yojna.code,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          yojna.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: StatusPill(
                    yojna.isActive ? S.active : S.inactive,
                    tone: yojna.isActive ? PillTone.success : PillTone.neutral,
                  ),
                ),
                _YojnaMenu(yojna: yojna),
              ],
            ),
          ),
          if (yojna.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                yojna.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: c.border),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Metric(
                      label: S.membersCount,
                      value: Fmt.number(memberCount),
                    ),
                  ),
                  VerticalDivider(width: 1, color: c.border),
                  Expanded(
                    child: _Metric(
                      label: 'Reg. fee',
                      value: Fmt.money(yojna.registrationFee),
                    ),
                  ),
                  VerticalDivider(width: 1, color: c.border),
                  Expanded(
                    child: _Metric(
                      label: 'Claim',
                      value: Fmt.moneyCompact(yojna.claimAmount),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: () =>
                      showYojnaFormDialog(context, existing: yojna),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text(S.edit),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                fontFeatures: kTabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YojnaMenu extends ConsumerWidget {
  const _YojnaMenu({required this.yojna});

  final Yojna yojna;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PopupMenuButton<int>(
      tooltip: S.actions,
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.more_horiz, size: 19),
      onSelected: (value) async {
        switch (value) {
          case 0:
            showYojnaFormDialog(context, existing: yojna);
          case 1:
            await ref
                .read(yojnaListProvider.notifier)
                .edit(yojna.copyWith(isActive: !yojna.isActive));
          case 2:
            final members =
                ref.read(membersPerYojnaProvider).value?[yojna.id] ?? 0;
            if (members > 0) {
              showToast(
                context,
                'This Yojna has $members members, so it cannot be deleted. '
                'Deactivate it instead.',
                error: true,
              );
              return;
            }
            final ok = await confirmDialog(
              context,
              title: 'Delete Yojna?',
              message: S.confirmDeleteBody,
            );
            if (!ok || !context.mounted) return;
            await runWithToast(
              context,
              () => ref.read(yojnaListProvider.notifier).remove(yojna.id),
              success: 'Yojna deleted',
            );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text(S.edit)),
        PopupMenuItem(
          value: 1,
          child: Text(yojna.isActive ? 'Deactivate' : 'Activate'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text(S.delete, style: TextStyle(color: c.danger)),
        ),
      ],
    );
  }
}
