import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/whatsapp.dart';
import '../../data/models/models.dart';
import '../../state/agent_providers.dart';
import '../../state/auth_controller.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../../widgets/stat_card.dart';
import 'agent_forms.dart';

/// Dues per closing group and the agent's death reports
/// (IMPLEMENTATION_PLAN Phase 13).
class AgentDuesPage extends ConsumerWidget {
  const AgentDuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agentClosingGroupsProvider);
    final page = async.value ?? PageResult.empty<ClosingGroupDues>();
    final reports = ref.watch(agentDeathReportsProvider).value ?? const [];

    void open(ClosingGroupDues g) => context.go(
          Uri(
            path: AppRoutes.agentDuesGroup,
            queryParameters: {'yojna': g.yojnaId, 'group': g.closingGroup},
          ).toString(),
        );

    return PageBody(
      maxWidth: 960,
      children: [
        const SectionHeader(
          title: S.dues,
          subtitle: 'Who still owes a contribution for each closing',
        ),
        const SizedBox(height: Space.xl),
        AppCard(
          child: async.hasError && async.value == null
              ? ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(agentClosingGroupsProvider),
                )
              : async.value == null
                  ? const LoadingState()
                  : ResponsiveTable<ClosingGroupDues>(
                      rows: page.items,
                      totalCount: page.total,
                      pageSize: agentListPageSize,
                      page: ref.watch(agentDuesPageProvider),
                      onPageChanged:
                          ref.read(agentDuesPageProvider.notifier).set,
                      busy: async.isLoading,
                      emptyMessage:
                          'No closings yet, so none of your members owe anything.',
                      emptyIcon: Icons.event_available_outlined,
                      onRowTap: open,
                      mobileTitle: (g) => g.closingGroup,
                      mobileSubtitle: (g) =>
                          '${g.yojnaName} · ${Fmt.date(g.closingDate)} · '
                          '${g.paidCount}/${g.memberCount} paid',
                      mobileTrailing: (context, g) => _ToCollect(group: g),
                      columns: [
                        TableCol<ClosingGroupDues>(
                          label: S.closingGroup,
                          minWidth: 130,
                          text: (g) => g.closingGroup,
                          cell: (context, g) => Text(
                            g.closingGroup,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        TableCol<ClosingGroupDues>(
                          label: S.scheme,
                          flex: 2,
                          minWidth: 150,
                          text: (g) => g.yojnaName,
                          cell: (context, g) => Text(
                            g.yojnaName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TableCol<ClosingGroupDues>(
                          label: S.closingDate,
                          minWidth: 110,
                          text: (g) => Fmt.date(g.closingDate),
                          cell: (context, g) => Text(Fmt.date(g.closingDate)),
                        ),
                        TableCol<ClosingGroupDues>(
                          label: 'Paid',
                          minWidth: 90,
                          numeric: true,
                          text: (g) => '${g.paidCount}/${g.memberCount}',
                          cell: (context, g) =>
                              Text('${g.paidCount}/${g.memberCount}'),
                        ),
                        TableCol<ClosingGroupDues>(
                          label: S.toCollect,
                          minWidth: 120,
                          numeric: true,
                          cell: (context, g) => _ToCollect(group: g),
                        ),
                      ],
                    ),
        ),
        if (reports.isNotEmpty) ...[
          const SizedBox(height: Space.xxl),
          const SectionHeader(title: S.deathReports, dense: true),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              children: [
                for (final (i, r) in reports.indexed) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.border),
                  _DeathReportTile(report: r),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ToCollect extends StatelessWidget {
  const _ToCollect({required this.group});

  final ClosingGroupDues group;

  @override
  Widget build(BuildContext context) {
    if (group.toCollect <= 0) {
      return StatusPill(
        group.pendingCount > 0 ? 'Collected' : 'All paid',
        tone: PillTone.success,
      );
    }
    return Text(
      Fmt.money(group.toCollect),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: context.colors.warning,
      ),
    );
  }
}

class _DeathReportTile extends StatelessWidget {
  const _DeathReportTile({required this.report});

  final ClosingRequest report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final tone = switch (r.status) {
      RequestStatus.pending => PillTone.warning,
      RequestStatus.approved => PillTone.success,
      RequestStatus.rejected => PillTone.danger,
    };
    return ListTile(
      title: Text(r.memberName),
      subtitle: Text(
        [
          '${S.dateOfDeath}: ${Fmt.date(r.dateOfDeath)}',
          if (r.decisionNote.isNotEmpty) 'Office: ${r.decisionNote}',
        ].join('\n'),
      ),
      isThreeLine: r.decisionNote.isNotEmpty,
      trailing: StatusPill(r.status.label, tone: tone),
      onTap: r.certificateUrl.isEmpty
          ? null
          : () => launchUrl(
                Uri.parse(r.certificateUrl),
                mode: LaunchMode.externalApplication,
              ),
    );
  }
}

// ---------------------------------------------------------------------------
// One closing group
// ---------------------------------------------------------------------------

class AgentGroupDuesPage extends ConsumerStatefulWidget {
  const AgentGroupDuesPage({
    super.key,
    required this.yojnaId,
    required this.closingGroup,
  });

  final String yojnaId;
  final String closingGroup;

  @override
  ConsumerState<AgentGroupDuesPage> createState() => _AgentGroupDuesPageState();
}

class _AgentGroupDuesPageState extends ConsumerState<AgentGroupDuesPage> {
  /// Opens on who still has to pay.
  DueState? _filter = DueState.due;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      agentGroupDuesProvider((widget.yojnaId, widget.closingGroup)),
    );
    final all = async.value ?? const <MemberDue>[];
    final shown =
        all.where((d) => _filter == null || d.state == _filter).toList();
    final yojna = (ref.watch(agentYojnasProvider).value ?? const <Yojna>[])
        .where((y) => y.id == widget.yojnaId)
        .firstOrNull;
    int count(DueState s) => all.where((d) => d.state == s).length;

    return PageBody(
      maxWidth: 960,
      children: [
        SectionHeader(
          title: widget.closingGroup,
          subtitle: [
            yojna?.name ?? '',
            if (all.isNotEmpty) 'Closing ${Fmt.date(all.first.closingDate)}',
          ].where((s) => s.isNotEmpty).join(' · '),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.go(AppRoutes.agentDues),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: Space.xl),
        StatGrid(
          children: [
            StatCard(
              label: S.toCollect,
              value: Fmt.money(all.fold<double>(0, (s, d) => s + d.toCollect)),
              icon: Icons.currency_rupee_rounded,
              accent: StatAccent.amber,
              caption: '${count(DueState.due)} members',
              onTap: () => setState(() => _filter = DueState.due),
            ),
            StatCard(
              label: S.waitingApproval,
              value: Fmt.number(count(DueState.pending)),
              icon: Icons.hourglass_top_rounded,
              accent: StatAccent.blue,
              caption: 'members',
              onTap: () => setState(() => _filter = DueState.pending),
            ),
            StatCard(
              label: 'Paid',
              value: '${count(DueState.paid)}/${all.length}',
              icon: Icons.verified_outlined,
              accent: StatAccent.green,
              caption: 'members',
              onTap: () => setState(() => _filter = DueState.paid),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterMenu<DueState>(
            label: S.status,
            value: _filter,
            items: DueState.values,
            itemLabel: (s) => s.label,
            onChanged: (s) => setState(() => _filter = s),
          ),
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: async.hasError && async.value == null
              ? ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(agentGroupDuesProvider),
                )
              : async.value == null
                  ? const LoadingState()
                  : shown.isEmpty
                      ? EmptyState(
                          message: _filter == DueState.due
                              ? 'Nobody still owes for this closing.'
                              : S.noResults,
                          icon: Icons.task_alt_rounded,
                        )
                      : Column(
                          children: [
                            for (final (i, d) in shown.indexed) ...[
                              if (i > 0)
                                Divider(height: 1, color: context.colors.border),
                              _DueRow(due: d, yojnaName: yojna?.name ?? ''),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.due, required this.yojnaName});

  final MemberDue due;
  final String yojnaName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final d = due;
    final (label, tone) = switch (d.state) {
      DueState.due => ('${Fmt.money(d.toCollect)} due', PillTone.warning),
      DueState.pending => (DueState.pending.label, PillTone.info),
      DueState.paid => (DueState.paid.label, PillTone.success),
    };

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.lg,
        runSpacing: Space.sm,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.memberName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [d.regNo, Fmt.phone(d.phone), d.village]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 6),
                StatusPill(label, tone: tone),
              ],
            ),
          ),
          if (d.state == DueState.due)
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => sendOnWhatsApp(
                    context,
                    phone: d.phone,
                    text: WhatsApp.duesReminder(
                      due: d,
                      yojnaName: yojnaName,
                      agentName: ref.read(currentUserProvider).name,
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 17),
                  label: const Text(S.sendReminder),
                ),
                FilledButton.icon(
                  onPressed: () => showAgentPaymentForm(
                    context,
                    member: _memberOf(d),
                    closingCaseId: d.closingCaseId,
                  ),
                  icon: const Icon(Icons.currency_rupee_rounded, size: 17),
                  label: const Text('Collect'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Enough of the member for the payment form, which only shows who pays.
Member _memberOf(MemberDue d) => Member(
      id: d.memberId,
      yojnaId: d.yojnaId,
      regNo: d.regNo,
      name: d.memberName,
      fatherOrHusbandName: '',
      jati: '',
      warisName: '',
      warisRelation: '',
      primaryPhone: d.phone,
      aadhaar: '',
      village: d.village,
      joinDate: d.closingDate,
    );
