import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/forms/agent_form_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../../widgets/stat_card.dart';

class AgentsPage extends ConsumerWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agentsProvider);
    final agents = ref.watch(filteredAgentsProvider);
    final all = ref.watch(agentsProvider).value ?? const <Agent>[];
    final counts = ref.watch(memberCountByAgentProvider);
    final collections = ref.watch(collectionByAgentProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.agents,
          subtitle: S.agentsSub,
          actions: [
            FilledButton.icon(
              onPressed: () => showAgentFormDialog(context),
              icon: const Icon(Icons.person_add_alt, size: 17),
              label: const Text(S.addAgent),
            ),
          ],
        ),
        const SizedBox(height: 18),
        StatGrid(
          children: [
            StatCard(
              label: S.totalAgents,
              value: Fmt.number(all.length),
              icon: Icons.badge_outlined,
            ),
            StatCard(
              label: 'Active agents',
              value: Fmt.number(all.where((a) => a.isActive).length),
              icon: Icons.verified_user_outlined,
              tone: PillTone.success,
            ),
            StatCard(
              label: 'Total collected',
              value: Fmt.moneyCompact(
                collections.values.fold<double>(0, (a, b) => a + b),
              ),
              icon: Icons.savings_outlined,
              tone: PillTone.warning,
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: SearchField(
            hint: 'नाम, कोड, फ़ोन, क्षेत्र…',
            onChanged: ref.read(agentQueryProvider.notifier).set,
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Builder(
            builder: (context) {
              if (async.isLoading && async.value == null) {
                return const LoadingState();
              }
              if (async.hasError && async.value == null) {
                return ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(agentsProvider),
                );
              }
              return ResponsiveTable<Agent>(
                rows: agents,
                pageSize: 12,
                onRowTap: (a) => _showAgentDetails(context, ref, a),
                mobileTitle: (a) => a.name,
                mobileSubtitle: (a) => a.code,
                mobileLeading: (context, a) => AppAvatar(name: a.name),
                columns: [
                  TableCol<Agent>(
                    label: S.code,
                    width: 90,
                    text: (a) => a.code,
                    cell: (context, a) => Text(
                      a.code,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.name,
                    flex: 2,
                    minWidth: 180,
                    text: (a) => a.name,
                    cell: (context, a) => Row(
                      children: [
                        if (!context.isMobile) ...[
                          AppAvatar(name: a.name, size: 32),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.phone,
                    minWidth: 125,
                    text: (a) => Fmt.phone(a.phone),
                    cell: (context, a) => Text(
                      Fmt.phone(a.phone),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.area,
                    minWidth: 130,
                    hideBelow: ScreenSize.laptop,
                    text: (a) => [a.area, a.district]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    cell: (context, a) => Text(
                      [a.area, a.district].where((s) => s.isNotEmpty).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.membersCount,
                    minWidth: 100,
                    numeric: true,
                    text: (a) => '${counts[a.id] ?? 0}',
                    cell: (context, a) => Text(
                      '${counts[a.id] ?? 0}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TableCol<Agent>(
                    label: 'Collected',
                    minWidth: 120,
                    numeric: true,
                    hideBelow: ScreenSize.desktop,
                    text: (a) => Fmt.money(collections[a.id] ?? 0),
                    cell: (context, a) => Text(
                      Fmt.moneyCompact(collections[a.id] ?? 0),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.commission,
                    minWidth: 100,
                    numeric: true,
                    hideBelow: ScreenSize.desktop,
                    text: (a) => '${a.commissionPercent}%',
                    cell: (context, a) => Text(
                      '${a.commissionPercent}%',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.status,
                    minWidth: 95,
                    cell: (context, a) => StatusPill(
                      a.isActive ? S.active : S.inactive,
                      tone: a.isActive ? PillTone.success : PillTone.neutral,
                    ),
                  ),
                ],
                rowActions: (context, a) => _AgentActions(agent: a),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AgentActions extends ConsumerWidget {
  const _AgentActions({required this.agent});

  final Agent agent;

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
            _showAgentDetails(context, ref, agent);
          case 1:
            showAgentFormDialog(context, existing: agent);
          case 2:
            await ref
                .read(agentsProvider.notifier)
                .edit(agent.copyWith(isActive: !agent.isActive));
          case 3:
            final ok = await confirmDialog(
              context,
              message:
                  'Members assigned to this agent will be left unassigned.',
            );
            if (!ok) return;
            await ref.read(agentsProvider.notifier).remove(agent.id);
            if (context.mounted) showToast(context, 'Agent removed');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text(S.view)),
        const PopupMenuItem(value: 1, child: Text(S.edit)),
        PopupMenuItem(
          value: 2,
          child: Text(agent.isActive ? 'Deactivate' : 'Activate'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text(S.delete, style: TextStyle(color: c.danger)),
        ),
      ],
    );
  }
}

void _showAgentDetails(BuildContext context, WidgetRef ref, Agent a) {
  final counts = ref.read(memberCountByAgentProvider);
  final collections = ref.read(collectionByAgentProvider);
  final yojnas = ref.read(yojnaByIdProvider);

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: a.name,
      subtitle: a.code,
      icon: Icons.badge_outlined,
      maxWidth: 560,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            showAgentFormDialog(context, existing: a);
          },
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text(S.edit),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: a.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    StatusPill(
                      a.isActive ? S.active : S.inactive,
                      tone: a.isActive ? PillTone.success : PillTone.neutral,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DetailRow(label: S.phone, value: Fmt.phone(a.phone)),
          DetailRow(label: 'Email', value: a.email),
          DetailRow(
            label: S.area,
            value: [a.area, a.district].where((s) => s.isNotEmpty).join(', '),
          ),
          DetailRow(label: S.commission, value: '${a.commissionPercent}%'),
          DetailRow(label: S.membersCount, value: '${counts[a.id] ?? 0}'),
          DetailRow(
            label: 'Total collected',
            value: Fmt.money(collections[a.id] ?? 0),
          ),
          DetailRow(label: S.joinedOn, value: Fmt.date(a.joinDate)),
          const SizedBox(height: 10),
          const FieldLabel('Assigned Yojna'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: a.yojnaIds.isEmpty
                ? const [StatusPill('All schemes', tone: PillTone.neutral)]
                : [
                    for (final id in a.yojnaIds)
                      StatusPill(yojnas[id]?.name ?? id, tone: PillTone.brand),
                  ],
          ),
        ],
      ),
    ),
  );
}
