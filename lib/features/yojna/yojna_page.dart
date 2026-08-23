import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
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
    final counts = ref.watch(membersPerYojnaProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.yojna,
          subtitle: S.yojnaSub,
          actions: [
            FilledButton.icon(
              onPressed: () => showYojnaFormDialog(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('नई योजना'),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
              message: 'अभी तक कोई योजना नहीं बनाई गई',
              icon: Icons.workspaces_outline,
              action: FilledButton.icon(
                onPressed: () => showYojnaFormDialog(context),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('नई योजना बनाएँ'),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
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
    final selected = ref.watch(selectedYojnaIdProvider) == yojna.id;

    return AppCard(
      borderColor: selected ? c.brand : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  yojna.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.brand,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      yojna.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          yojna.isActive ? S.active : S.inactive,
                          tone: yojna.isActive
                              ? PillTone.success
                              : PillTone.neutral,
                        ),
                        if (selected)
                          const StatusPill('Selected', tone: PillTone.brand),
                      ],
                    ),
                  ],
                ),
              ),
              _YojnaMenu(yojna: yojna),
            ],
          ),
          if (yojna.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              yojna.description,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: S.membersCount,
                  value: Fmt.number(memberCount),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'सहयोग',
                  value: Fmt.money(yojna.contributionAmount),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'क्लेम',
                  value: Fmt.moneyCompact(yojna.claimAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(selectedYojnaIdProvider.notifier)
                      .select(yojna.id),
                  icon: const Icon(Icons.filter_center_focus, size: 15),
                  label: const Text('Set scope'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      showYojnaFormDialog(context, existing: yojna),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text(S.edit),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ),
      ],
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
            final members = ref.read(membersPerYojnaProvider)[yojna.id] ?? 0;
            final ok = await confirmDialog(
              context,
              title: 'योजना हटाएँ?',
              message: members > 0
                  ? 'इस योजना में $members सदस्य हैं। हटाने पर वे किसी योजना से नहीं जुड़े रहेंगे।'
                  : S.confirmDeleteBody,
            );
            if (!ok) return;
            await ref.read(yojnaListProvider.notifier).remove(yojna.id);
            if (context.mounted) showToast(context, 'योजना हटाई गई');
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
