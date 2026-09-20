import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/whatsapp.dart';
import '../../data/models/models.dart';
import '../../data/repositories/agent_repository.dart';
import '../../state/agent_providers.dart';
import '../../state/auth_controller.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../../widgets/stat_card.dart';
import '../certificate/certificate_action.dart';
import '../dashboard/dashboard_page.dart' show PaymentStatusPill;
import '../members/members_page.dart' show MemberStatusPill;
import 'agent_cash.dart';
import 'agent_forms.dart';

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class AgentHomePage extends ConsumerWidget {
  const AgentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(agentSummaryProvider).value ?? AgentSummary.empty;

    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(
          title: 'Namaste, ${user.name}',
          subtitle: '${S.trustName} · ${user.role.label}',
        ),
        const SizedBox(height: Space.xl),
        StatGrid(
          children: [
            StatCard(
              label: S.myMembers,
              value: Fmt.number(summary.activeMembers),
              icon: Icons.people_outline,
              accent: StatAccent.blue,
              caption: summary.pendingMembers == 0
                  ? null
                  : '${summary.pendingMembers} waiting for approval',
              onTap: () => context.go(AppRoutes.agentMembers),
            ),
            StatCard(
              label: S.waitingApproval,
              value: Fmt.money(summary.pendingAmount),
              icon: Icons.hourglass_top_rounded,
              accent: StatAccent.amber,
              caption: '${summary.pendingPayments} receipts',
              onTap: () => context.go(AppRoutes.agentCollections),
            ),
            StatCard(
              label: S.approvedThisMonth,
              value: Fmt.money(summary.monthApproved),
              icon: Icons.verified_outlined,
              accent: StatAccent.green,
            ),
            StatCard(
              label: S.cashInHand,
              value: Fmt.money(summary.cashInHand),
              icon: Icons.account_balance_wallet_outlined,
              accent: StatAccent.purple,
              caption: summary.handoverWaiting == 0
                  ? null
                  : '${Fmt.money(summary.handoverWaiting)} waiting to be '
                      'confirmed',
              onTap: () => context.go(AppRoutes.agentCollections),
            ),
            StatCard(
              label: S.thisMonthCommission,
              value: Fmt.money(summary.monthCommission),
              icon: Icons.percent_rounded,
              accent: StatAccent.blue,
              caption: 'So far this month',
              onTap: () => context.go(AppRoutes.agentCollections),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            FilledButton.icon(
              onPressed: () => showAgentPaymentForm(context),
              icon: const Icon(Icons.currency_rupee_rounded, size: 17),
              label: const Text(S.recordPayment),
            ),
            OutlinedButton.icon(
              onPressed: () => showAgentMemberForm(context),
              icon: const Icon(Icons.person_add_alt, size: 17),
              label: const Text(S.addMember),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const _RecentClosings(),
        const SizedBox(height: Space.xl),
        Text(
          'Money you collect and members you add count in the trust totals '
          'after the office approves them.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

/// The three newest closing groups the agent's members owe for, so the home
/// page shows what to collect next without opening the Dues tab.
class _RecentClosings extends ConsumerWidget {
  const _RecentClosings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final groups = ref.watch(agentClosingGroupsProvider).value?.items ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recent closings',
          dense: true,
          actions: [
            TextButton(
              onPressed: () => context.go(AppRoutes.agentDues),
              child: const Text(S.viewAll),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: Column(
            children: [
              for (final (i, g) in groups.take(3).indexed) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: 4,
                  ),
                  title: Text(
                    '${g.closingGroup} · ${g.yojnaName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${g.paidCount} of ${g.memberCount} paid · '
                    '${Fmt.date(g.closingDate)}',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  trailing: Text(
                    Fmt.money(g.toCollect),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: g.toCollect > 0 ? c.warning : c.textSecondary,
                    ),
                  ),
                  onTap: () => context.go(
                    '${AppRoutes.agentDuesGroup}?yojna=${g.yojnaId}'
                    '&group=${Uri.encodeComponent(g.closingGroup)}',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// My Members
// ---------------------------------------------------------------------------

class AgentMembersPage extends ConsumerWidget {
  const AgentMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agentMembersProvider);
    final page = async.value ?? PageResult.empty<Member>();

    return PageBody(
      maxWidth: 960,
      children: [
        SectionHeader(
          title: S.myMembers,
          subtitle: S.myMembersSub,
          actions: [
            FilledButton.icon(
              onPressed: () => showAgentMemberForm(context),
              icon: const Icon(Icons.person_add_alt, size: 17),
              label: const Text(S.addMember),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        FilterBar(
          search: SearchField(
            hint: 'Name, reg no, phone, village…',
            value: ref.read(agentMemberTextProvider),
            onChanged: ref.read(agentMemberTextProvider.notifier).set,
          ),
          filters: [
            FilterMenu<MemberStatus>(
              label: S.status,
              value: ref.watch(agentMemberStatusProvider),
              items: MemberStatus.values,
              itemLabel: (s) => s.label,
              onChanged: ref.read(agentMemberStatusProvider.notifier).set,
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: async.hasError && async.value == null
              ? ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(agentMembersProvider),
                )
              : async.value == null
                  ? const LoadingState()
                  : ResponsiveTable<Member>(
                      rows: page.items,
                      totalCount: page.total,
                      pageSize: agentListPageSize,
                      page: ref.watch(agentMemberPageProvider),
                      onPageChanged:
                          ref.read(agentMemberPageProvider.notifier).set,
                      busy: async.isLoading,
                      emptyMessage: 'No members yet. Add your first member.',
                      onRowTap: (m) => _showMember(context, m),
                      mobileTitle: (m) => m.name,
                      mobileSubtitle: (m) => [m.regNo, Fmt.phone(m.primaryPhone)]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      mobileTrailing: (context, m) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: MemberStatusPill(status: m.status),
                      ),
                      columns: [
                        TableCol<Member>(
                          label: S.memberName,
                          flex: 2,
                          minWidth: 180,
                          text: (m) => m.name,
                          cell: (context, m) => Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        TableCol<Member>(
                          label: S.regNo,
                          minWidth: 130,
                          text: (m) => m.regNo.isEmpty ? '—' : m.regNo,
                          cell: (context, m) =>
                              Text(m.regNo.isEmpty ? '—' : m.regNo),
                        ),
                        TableCol<Member>(
                          label: S.phone,
                          minWidth: 125,
                          text: (m) => Fmt.phone(m.primaryPhone),
                          cell: (context, m) => Text(Fmt.phone(m.primaryPhone)),
                        ),
                        TableCol<Member>(
                          label: S.status,
                          minWidth: 100,
                          cell: (context, m) => MemberStatusPill(status: m.status),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

void _showMember(BuildContext context, Member m) {
  final canPay = m.status == MemberStatus.active ||
      m.status == MemberStatus.pending;

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: m.name,
      subtitle: m.regNo.isEmpty ? m.status.label : m.regNo,
      maxWidth: 560,
      actions: [
        if (m.status == MemberStatus.active)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showDeathReportForm(context, m);
            },
            child: const Text(S.reportDeath),
          ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            showContactForm(context, m);
          },
          child: const Text(S.editContact),
        ),
        // Members enrolled by this agent carry their name as the karyakarta.
        if (m.regNo.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => OutlinedButton(
              onPressed: () => printMemberCertificate(
                context,
                member: m,
                yojna: ref
                    .watch(agentYojnasProvider)
                    .value
                    ?.where((y) => y.id == m.yojnaId)
                    .firstOrNull,
                agentName: ref.watch(currentUserProvider).name,
              ),
              child: const Text(S.printCertificate),
            ),
          ),
        if (canPay)
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showAgentPaymentForm(context, member: m);
            },
            child: const Text(S.recordPayment),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberStatusPill(status: m.status),
          if (m.reviewNote.isNotEmpty)
            DetailRow(label: 'Office note', value: m.reviewNote),
          const SizedBox(height: 8),
          DetailRow(label: S.fldFather, value: m.fatherOrHusbandName),
          DetailRow(
            label: 'Nominee',
            value: [m.warisName, m.warisRelation]
                .where((s) => s.isNotEmpty)
                .join(' · '),
          ),
          if (m.dob != null) DetailRow(label: S.fldDob, value: Fmt.date(m.dob)),
          DetailRow(label: S.phone, value: Fmt.phone(m.primaryPhone)),
          if (m.altPhone.isNotEmpty)
            DetailRow(label: S.fldAltPhone, value: Fmt.phone(m.altPhone)),
          DetailRow(
            label: 'Address',
            value: [m.address, m.state].where((s) => s.isNotEmpty).join(', '),
          ),
          DetailRow(label: S.joinedOn, value: Fmt.date(m.joinDate)),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Collections
// ---------------------------------------------------------------------------

class AgentCollectionsPage extends ConsumerWidget {
  const AgentCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agentPaymentsProvider);
    final page = async.value ?? PaymentPage.empty;

    String memberName(Payment p) => page.members[p.memberId]?.name ?? '';

    return PageBody(
      maxWidth: 960,
      children: [
        SectionHeader(
          title: S.collections,
          subtitle: 'Receipts you issued',
          actions: [
            FilledButton.icon(
              onPressed: () => showAgentPaymentForm(context),
              icon: const Icon(Icons.currency_rupee_rounded, size: 17),
              label: const Text(S.recordPayment),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const AgentCashSection(),
        const SizedBox(height: Space.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterMenu<PaymentStatus>(
              label: S.status,
              value: ref.watch(agentPaymentStatusProvider),
              items: PaymentStatus.values,
              itemLabel: (s) => s.label,
              onChanged: ref.read(agentPaymentStatusProvider.notifier).set,
          ),
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: async.hasError && async.value == null
              ? ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(agentPaymentsProvider),
                )
              : async.value == null
                  ? const LoadingState()
                  : ResponsiveTable<Payment>(
                      rows: page.items,
                      totalCount: page.total,
                      pageSize: agentListPageSize,
                      page: ref.watch(agentPaymentPageProvider),
                      onPageChanged:
                          ref.read(agentPaymentPageProvider.notifier).set,
                      busy: async.isLoading,
                      emptyMessage: 'No receipts yet.',
                      onRowTap: (p) => _showReceipt(context, p, page.members[p.memberId]),
                      mobileTitle: (p) =>
                          '${p.receiptNo} · ${Fmt.money(p.amount)}',
                      mobileSubtitle: (p) =>
                          '${memberName(p)} · ${Fmt.date(p.date)}',
                      mobileTrailing: (context, p) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _ReceiptStatus(payment: p),
                      ),
                      columns: [
                        TableCol<Payment>(
                          label: 'Receipt',
                          minWidth: 110,
                          text: (p) => p.receiptNo,
                          cell: (context, p) => Text(p.receiptNo),
                        ),
                        TableCol<Payment>(
                          label: S.memberName,
                          flex: 2,
                          minWidth: 170,
                          text: memberName,
                          cell: (context, p) => Text(
                            memberName(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TableCol<Payment>(
                          label: S.amount,
                          minWidth: 100,
                          numeric: true,
                          text: (p) => Fmt.money(p.amount),
                          cell: (context, p) => Text(Fmt.money(p.amount)),
                        ),
                        TableCol<Payment>(
                          label: S.date,
                          minWidth: 110,
                          text: (p) => Fmt.date(p.date),
                          cell: (context, p) => Text(Fmt.date(p.date)),
                        ),
                        TableCol<Payment>(
                          label: S.status,
                          minWidth: 130,
                          cell: (context, p) => _ReceiptStatus(payment: p),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _ReceiptStatus extends StatelessWidget {
  const _ReceiptStatus({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    if (payment.hasOpenCancelRequest) {
      return const StatusPill(S.cancelRequested, tone: PillTone.warning);
    }
    return PaymentStatusPill(
      status: payment.status,
      cancelled: payment.isCancelled,
    );
  }
}

void _showReceipt(BuildContext context, Payment p, MemberRef? member) {
  final canRequestCancel = !p.isCancelled &&
      p.cancelRequestedAt == null &&
      p.status != PaymentStatus.failed;

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) => AppDialog(
        title: p.receiptNo,
        subtitle: member?.name ?? '',
        maxWidth: 520,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (member != null && p.status != PaymentStatus.failed)
            OutlinedButton.icon(
              onPressed: () => sendOnWhatsApp(
                dialogContext,
                phone: member.primaryPhone,
                text: WhatsApp.receiptMessage(
                  memberName: member.name,
                  payment: p,
                ),
              ),
              icon: const Icon(Icons.chat_outlined, size: 17),
              label: const Text(S.shareReceipt),
            ),
          if (canRequestCancel)
            FilledButton(
              onPressed: () async {
                final reason = await reasonDialog(
                  context,
                  title: '${S.requestCancel}: ${p.receiptNo}?',
                  message: 'The office decides whether to cancel it.',
                  confirmLabel: S.requestCancel,
                );
                if (reason == null || !context.mounted) return;
                try {
                  await ref
                      .read(agentActionsProvider)
                      .requestCancel(p.id, reason);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) showToast(context, 'Cancel requested');
                } catch (e) {
                  if (context.mounted) showToast(context, '$e', error: true);
                }
              },
              child: const Text(S.requestCancel),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReceiptStatus(payment: p),
            const SizedBox(height: 8),
            DetailRow(label: S.amount, value: Fmt.money(p.amount)),
            DetailRow(label: 'Type', value: p.kind.label),
            if (p.closingGroup.isNotEmpty)
              DetailRow(label: S.forClosing, value: p.closingGroup),
            DetailRow(label: S.mode, value: p.mode.label),
            if (p.reference.isNotEmpty)
              DetailRow(label: 'UTR / cheque no', value: p.reference),
            DetailRow(label: S.date, value: Fmt.date(p.date)),
            if (p.rejectReason.isNotEmpty)
              DetailRow(label: 'Rejected because', value: p.rejectReason),
            if (p.cancelRequestReason.isNotEmpty)
              DetailRow(label: 'Cancel reason', value: p.cancelRequestReason),
            if (p.isCancelled)
              DetailRow(label: 'Cancelled because', value: p.cancelReason),
          ],
        ),
      ),
    ),
  );
}
