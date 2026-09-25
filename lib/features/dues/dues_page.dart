import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/forms/payment_form_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../../widgets/stat_card.dart';
import '../export/export_actions.dart';
import '../export/export_button.dart';

/// Every member of the Yojna picked in the top bar with what they still owe
/// for its closings, what they have contributed so far, and a way to record
/// the next payment.
class DuesPage extends ConsumerWidget {
  const DuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(duesPageProvider);
    final page = async.value ?? PageResult.empty<MemberDuesSummary>();
    final totals = ref.watch(duesTotalsProvider).value ?? DuesTotals.empty;
    final agents = ref.watch(agentByIdProvider);
    final yojnas = ref.watch(yojnaByIdProvider);
    final selectedYojna = ref.watch(selectedYojnaProvider);
    final filters = ref.read(duesFilterProvider.notifier);

    return PageBody(
      children: [
        SectionHeader(
          title: S.dues,
          subtitle: [
            selectedYojna?.name ?? S.allYojnas,
            'Who still owes for closings',
          ].join(' · '),
          actions: [
            ExportCsvButton(onPressed: () => exportDuesCsv(context, ref)),
          ],
        ),
        const SizedBox(height: Space.xl),
        StatGrid(
          children: [
            StatCard(
              label: 'Members owing',
              value: Fmt.number(totals.owingCount),
              icon: Icons.group_outlined,
              accent: StatAccent.amber,
              caption: 'of ${Fmt.number(totals.memberCount)} members',
              onTap: () => filters.setStanding(DuesStanding.owing),
            ),
            StatCard(
              label: 'Total due',
              value: Fmt.money(totals.due),
              icon: Icons.currency_rupee_rounded,
              accent: StatAccent.red,
              caption: 'Unpaid contributions',
              onTap: () => filters.setStanding(DuesStanding.owing),
            ),
            StatCard(
              label: S.waitingApproval,
              value: Fmt.money(totals.pending),
              icon: Icons.hourglass_top_rounded,
              accent: StatAccent.blue,
              caption: 'Collected, not approved yet',
            ),
            StatCard(
              label: 'Contributed',
              value: Fmt.money(totals.contributed),
              icon: Icons.verified_outlined,
              accent: StatAccent.green,
              caption: 'Every approved contribution',
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const _DuesFilters(),
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
                  onRetry: () => ref.invalidate(duesPageProvider),
                );
              }
              return ResponsiveTable<MemberDuesSummary>(
                rows: page.items,
                totalCount: page.total,
                pageSize: listPageSize,
                page: ref.watch(duesPageNumberProvider),
                onPageChanged: ref.read(duesPageNumberProvider.notifier).set,
                busy: async.isLoading,
                emptyMessage: 'No members match these filters.',
                emptyIcon: Icons.task_alt_rounded,
                onRowTap: (s) => showMemberDuesDialog(context, ref, s),
                mobileTitle: (s) => s.name,
                mobileSubtitle: (s) => [
                  s.regNo,
                  'Contributed ${Fmt.money(s.contributed)}',
                ].where((t) => t.isNotEmpty).join(' · '),
                mobileTrailing: (context, s) => Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: _DueAmount(summary: s),
                ),
                columns: [
                  TableCol<MemberDuesSummary>(
                    label: S.memberName,
                    flex: 2,
                    minWidth: 190,
                    text: (s) => s.name,
                    cell: (context, s) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          s.regNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TableCol<MemberDuesSummary>(
                    label: S.phone,
                    minWidth: 125,
                    hideBelow: ScreenSize.laptop,
                    text: (s) => Fmt.phone(s.phone),
                    cell: (context, s) => Text(Fmt.phone(s.phone)),
                  ),
                  if (selectedYojna == null)
                    TableCol<MemberDuesSummary>(
                      label: S.scheme,
                      minWidth: 150,
                      hideBelow: ScreenSize.desktop,
                      text: (s) => yojnas[s.yojnaId]?.name ?? '—',
                      cell: (context, s) => Text(
                        yojnas[s.yojnaId]?.name ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  TableCol<MemberDuesSummary>(
                    label: S.agent,
                    minWidth: 140,
                    hideBelow: ScreenSize.laptop,
                    text: (s) => agents[s.agentId]?.name ?? '—',
                    cell: (context, s) => Text(
                      agents[s.agentId]?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TableCol<MemberDuesSummary>(
                    label: 'Closings owed',
                    minWidth: 115,
                    numeric: true,
                    text: (s) => Fmt.number(s.closingsOwed),
                    cell: (context, s) => Text(Fmt.number(s.closingsOwed)),
                  ),
                  TableCol<MemberDuesSummary>(
                    label: 'Contributed',
                    minWidth: 120,
                    numeric: true,
                    showOnMobile: false,
                    text: (s) => Fmt.money(s.contributed),
                    cell: (context, s) => Text(Fmt.money(s.contributed)),
                  ),
                  TableCol<MemberDuesSummary>(
                    label: 'Total due',
                    minWidth: 130,
                    numeric: true,
                    showOnMobile: false,
                    cell: (context, s) => _DueAmount(summary: s),
                  ),
                ],
                rowActions: (context, s) =>
                    _PayButton(onPressed: () => recordDuesPayment(context, ref, s)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DuesFilters extends ConsumerWidget {
  const _DuesFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(duesFilterProvider);
    final notifier = ref.read(duesFilterProvider.notifier);
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];

    return FilterBar(
      search: SearchField(
        hint: 'Name, reg no, phone, village…',
        value: filter.query,
        onChanged: notifier.setQuery,
      ),
      filters: [
        FilterMenu<DuesStanding>(
          label: S.status,
          value: filter.standing,
          items: DuesStanding.values,
          itemLabel: (s) => s.label,
          onChanged: notifier.setStanding,
        ),
        FilterMenu<Agent>(
          label: S.agent,
          value: agents.firstWhereOrNull((a) => a.id == filter.agentId),
          items: agents,
          itemLabel: (a) => a.name,
          onChanged: (a) => notifier.setAgent(a?.id),
        ),
      ],
      onClear: filter.isEmpty ? null : notifier.clear,
    );
  }
}

/// Soft blue like the top bar's New button, so a column of them stays calm.
class _PayButton extends StatelessWidget {
  const _PayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: c.brandSoft,
        foregroundColor: c.onBrandSoft,
      ),
      onPressed: onPressed,
      child: const Text('Pay'),
    );
  }
}

/// What the member still owes, with anything waiting for approval under it.
class _DueAmount extends StatelessWidget {
  const _DueAmount({required this.summary});

  final MemberDuesSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!summary.owes) return const StatusPill('Paid up', tone: PillTone.success);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fmt.money(summary.due),
          style: TextStyle(fontWeight: FontWeight.w600, color: c.warning),
        ),
        if (summary.pending > 0)
          Text(
            '${Fmt.money(summary.pending)} waiting',
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
      ],
    );
  }
}

/// Opens the payment form for [summary]'s member. For a contribution it picks
/// [due], or else the oldest closing still to collect, with what is left on it.
Future<void> recordDuesPayment(
  BuildContext context,
  WidgetRef ref,
  MemberDuesSummary summary, {
  MemberDue? due,
}) async {
  var closing = due;
  if (closing == null && summary.owes) {
    try {
      final dues =
          await ref.read(paymentActionsProvider).memberDues(summary.memberId);
      closing = dues.firstWhereOrNull((d) => d.toCollect > 0) ??
          dues.firstWhereOrNull((d) => d.due > 0);
    } catch (_) {
      // The form still opens; the admin picks the closing there.
    }
  }
  if (!context.mounted) return;
  final amount = closing == null
      ? summary.contributionAmount
      : (closing.toCollect > 0 ? closing.toCollect : closing.due);
  await showPaymentFormDialog(
    context,
    presetMember: summary.toMember(),
    presetClosingCaseId: closing?.closingCaseId,
    presetAmount: amount,
  );
}

/// Every closing the member owes for and their past contributions.
void showMemberDuesDialog(
  BuildContext context,
  WidgetRef ref,
  MemberDuesSummary summary,
) {
  final yojna = ref.read(yojnaByIdProvider)[summary.yojnaId];
  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: summary.name,
      subtitle: [summary.regNo, yojna?.name ?? '']
          .where((t) => t.isNotEmpty)
          .join(' · '),
      maxWidth: 680,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () => recordDuesPayment(dialogContext, ref, summary),
          icon: const Icon(Icons.currency_rupee_rounded, size: 16),
          label: const Text(S.recordPayment),
        ),
      ],
      child: _DuesBreakdown(summary: summary),
    ),
  );
}

class _DuesBreakdown extends ConsumerWidget {
  const _DuesBreakdown({required this.summary});

  final MemberDuesSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(memberDuesDetailProvider(summary.memberId));
    final detail = async.value;
    if (detail == null) {
      return async.hasError
          ? ErrorStateView(
              error: async.error!,
              onRetry: () =>
                  ref.invalidate(memberDuesDetailProvider(summary.memberId)),
            )
          : const LoadingState();
    }

    final dues = detail.dues;
    final cases = ref.watch(closingCasesProvider).value ?? const <ClosingCase>[];
    String groupOf(String? caseId) =>
        cases.firstWhereOrNull((c) => c.id == caseId)?.closingGroup ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.xxl,
          runSpacing: Space.md,
          children: [
            _Figure(
              label: 'Total due',
              value: Fmt.money(dues.fold<double>(0, (s, d) => s + d.due)),
              color: c.warning,
            ),
            _Figure(
              label: S.waitingApproval,
              value: Fmt.money(dues.fold<double>(0, (s, d) => s + d.pending)),
            ),
            _Figure(label: 'Contributed', value: Fmt.money(detail.contributed)),
          ],
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(title: 'Closings', dense: true),
        const SizedBox(height: Space.xs),
        if (dues.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text(
              'No closings to pay for yet.',
              style: TextStyle(color: c.textSecondary),
            ),
          )
        else
          for (final (i, d) in dues.reversed.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            _ClosingDueRow(
              due: d,
              onPay: () =>
                  recordDuesPayment(context, ref, summary, due: d),
            ),
          ],
        const SizedBox(height: Space.xl),
        const SectionHeader(title: 'Past contributions', dense: true),
        const SizedBox(height: Space.xs),
        if (detail.receipts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text(
              'No contributions yet.',
              style: TextStyle(color: c.textSecondary),
            ),
          )
        else
          for (final p in detail.receipts)
            DetailRow(
              label: [
                p.receiptNo,
                Fmt.date(p.date),
                groupOf(p.closingCaseId),
              ].where((t) => t.isNotEmpty).join(' · '),
              value: [
                Fmt.money(p.amount),
                if (p.isCancelled)
                  'Cancelled'
                else if (p.status != PaymentStatus.paid)
                  p.status.label,
              ].join(' · '),
            ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color ?? c.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// One closing group: what it asks, what is paid, and a Pay button while
/// something is still to collect.
class _ClosingDueRow extends StatelessWidget {
  const _ClosingDueRow({required this.due, required this.onPay});

  final MemberDue due;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = due;
    final (label, tone) = switch (d.state) {
      DueState.due => ('${Fmt.money(d.toCollect)} due', PillTone.warning),
      DueState.pending => (DueState.pending.label, PillTone.info),
      DueState.paid => (DueState.paid.label, PillTone.success),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.date(d.closingDate)} · ${Fmt.money(d.amount)} each'
                  '${d.paid > 0 ? ' · ${Fmt.money(d.paid)} paid' : ''}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 6),
                StatusPill(label, tone: tone),
              ],
            ),
          ),
          if (d.state == DueState.due) _PayButton(onPressed: onPay),
        ],
      ),
    );
  }
}
