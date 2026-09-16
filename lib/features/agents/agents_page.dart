import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
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
    final counts =
        ref.watch(memberCountByAgentProvider).value ?? const <String, int>{};
    final collections =
        ref.watch(collectionByAgentProvider).value ?? const <String, double>{};

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
        const SizedBox(height: Space.xl),
        StatGrid(
          children: [
            StatCard(
              label: S.totalAgents,
              value: Fmt.number(all.length),
              icon: Icons.badge_outlined,
              accent: StatAccent.blue,
            ),
            StatCard(
              label: 'Active agents',
              value: Fmt.number(all.where((a) => a.isActive).length),
              icon: Icons.verified_outlined,
              accent: StatAccent.green,
            ),
            StatCard(
              label: 'Total collected',
              icon: Icons.currency_rupee_rounded,
              accent: StatAccent.purple,
              value: Fmt.moneyCompact(
                collections.values.fold<double>(0, (a, b) => a + b),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        FilterBar(
          search: SearchField(
            hint: 'Name, code, phone, area…',
            onChanged: ref.read(agentQueryProvider.notifier).set,
          ),
        ),
        const SizedBox(height: Space.md),
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
                mobileTrailing: (context, a) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: StatusPill(
                    a.isActive ? S.active : S.inactive,
                    tone: a.isActive ? PillTone.success : PillTone.neutral,
                  ),
                ),
                columns: [
                  TableCol<Agent>(
                    label: S.code,
                    width: 90,
                    text: (a) => a.code,
                    cell: (context, a) => Text(
                      a.code,
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.name,
                    flex: 2,
                    minWidth: 180,
                    text: (a) => a.name,
                    showOnMobile: false,
                    cell: (context, a) => Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.phone,
                    minWidth: 125,
                    text: (a) => Fmt.phone(a.phone),
                    cell: (context, a) => Text(Fmt.phone(a.phone)),
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
                    ),
                  ),
                  TableCol<Agent>(
                    label: S.membersCount,
                    minWidth: 100,
                    numeric: true,
                    text: (a) => '${counts[a.id] ?? 0}',
                    cell: (context, a) => Text('${counts[a.id] ?? 0}'),
                  ),
                  TableCol<Agent>(
                    label: 'Collected',
                    minWidth: 120,
                    numeric: true,
                    hideBelow: ScreenSize.desktop,
                    text: (a) => Fmt.money(collections[a.id] ?? 0),
                    cell: (context, a) => Text(Fmt.moneyCompact(collections[a.id] ?? 0)),
                  ),
                  TableCol<Agent>(
                    label: S.commission,
                    minWidth: 100,
                    numeric: true,
                    hideBelow: ScreenSize.desktop,
                    text: (a) => '${a.commissionPercent}%',
                    cell: (context, a) => Text('${a.commissionPercent}%'),
                  ),
                  TableCol<Agent>(
                    label: S.status,
                    minWidth: 95,
                    showOnMobile: false,
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
    final isOwner = ref.watch(currentUserProvider).isOwner;
    final hasAccess =
        ref.watch(agentAccessProvider).value?.containsKey(agent.id) ?? false;
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
            if (!ok || !context.mounted) return;
            await runWithToast(
              context,
              () => ref.read(agentsProvider.notifier).remove(agent.id),
              success: 'Agent removed',
            );
          case 4:
            await _inviteAgent(context, ref, agent);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text(S.view)),
        const PopupMenuItem(value: 1, child: Text(S.edit)),
        PopupMenuItem(
          value: 2,
          child: Text(agent.isActive ? 'Deactivate' : 'Activate'),
        ),
        if (isOwner && !hasAccess)
          const PopupMenuItem(value: 4, child: Text(S.inviteToApp)),
        PopupMenuItem(
          value: 3,
          child: Text(S.delete, style: TextStyle(color: c.danger)),
        ),
      ],
    );
  }
}

/// Emails the agent an invite; after accepting it they sign in to the agent
/// screens with an email code.
Future<void> _inviteAgent(BuildContext context, WidgetRef ref, Agent agent) async {
  if (agent.email.trim().isEmpty) {
    showToast(context, S.inviteNeedsEmail, error: true);
    return;
  }
  final ok = await confirmDialog(
    context,
    title: S.inviteToApp,
    message: 'Send an invite to ${agent.email}? ${agent.name} will be able to '
        'sign in to the agent app with this email.',
    confirmLabel: 'Send invite',
    destructive: false,
  );
  if (!ok || !context.mounted) return;
  await runWithToast(
    context,
    () async {
      await ref.read(accessRepositoryProvider).inviteAgent(agent);
      ref.invalidate(agentAccessProvider);
    },
    success: S.inviteSent,
  );
}

String _accessLabel(Agent agent, Map<String, bool> access) {
  final on = access[agent.id];
  if (on == null) return S.accessNone;
  return on && agent.isActive ? S.accessActive : S.accessOff;
}

void _showAgentDetails(BuildContext context, WidgetRef ref, Agent a) {
  final access = ref.read(agentAccessProvider).value ?? const <String, bool>{};
  final counts =
      ref.read(memberCountByAgentProvider).value ?? const <String, int>{};
  final collections =
      ref.read(collectionByAgentProvider).value ?? const <String, double>{};
  final yojnas = ref.read(yojnaByIdProvider);

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: a.name,
      subtitle: a.code,
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
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              a.isActive ? S.active : S.inactive,
              tone: a.isActive ? PillTone.success : PillTone.neutral,
            ),
          ),
          const SizedBox(height: 8),
          DetailRow(label: S.phone, value: Fmt.phone(a.phone)),
          DetailRow(label: 'Email', value: a.email),
          DetailRow(
            label: S.area,
            value: [a.area, a.district].where((s) => s.isNotEmpty).join(', '),
          ),
          DetailRow(label: S.commission, value: '${a.commissionPercent}%'),
          DetailRow(label: S.appAccess, value: _accessLabel(a, access)),
          DetailRow(label: S.membersCount, value: '${counts[a.id] ?? 0}'),
          DetailRow(
            label: 'Total collected',
            value: Fmt.money(collections[a.id] ?? 0),
          ),
          DetailRow(label: S.joinedOn, value: Fmt.date(a.joinDate)),
          const SizedBox(height: 16),
          const FieldLabel('Assigned Yojna'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: a.yojnaIds.isEmpty
                ? const [StatusPill('All schemes', tone: PillTone.neutral)]
                : [
                    for (final id in a.yojnaIds)
                      StatusPill(yojnas[id]?.name ?? id),
                  ],
          ),
        ],
      ),
    ),
  );
}
