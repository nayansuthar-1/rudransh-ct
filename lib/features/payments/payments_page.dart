import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
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
import '../dashboard/dashboard_page.dart' show PaymentStatusPill;

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentsPageProvider);
    final page = async.value ?? PaymentPage.empty;
    final totals = ref.watch(paymentTotalsProvider).value ?? PaymentTotals.empty;
    final members = page.members;
    final agents = ref.watch(agentByIdProvider);
    final yojna = ref.watch(selectedYojnaProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.payments,
          subtitle: yojna?.name ?? S.allYojnas,
          actions: [
            FilledButton.icon(
              onPressed: () => showPaymentFormDialog(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text(S.addPayment),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        StatGrid(
          children: [
            StatCard(
              label: 'Transactions',
              value: Fmt.number(totals.count),
              icon: Icons.receipt_long_outlined,
              accent: StatAccent.blue,
            ),
            StatCard(
              label: 'Paid',
              value: Fmt.moneyCompact(totals.paid),
              icon: Icons.check_circle_outline,
              accent: StatAccent.green,
            ),
            StatCard(
              label: 'Pending',
              value: Fmt.moneyCompact(totals.pending),
              icon: Icons.schedule_rounded,
              accent: StatAccent.amber,
            ),
            StatCard(
              label: 'Failed',
              value: Fmt.moneyCompact(totals.failed),
              icon: Icons.error_outline,
              accent: StatAccent.red,
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        const _PaymentFilters(),
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
                  onRetry: () => ref.invalidate(paymentsPageProvider),
                );
              }
              return ResponsiveTable<Payment>(
                rows: page.items,
                totalCount: page.total,
                pageSize: listPageSize,
                page: ref.watch(paymentPageProvider),
                onPageChanged: ref.read(paymentPageProvider.notifier).set,
                busy: async.isLoading,
                mobileTitle: (p) => members[p.memberId]?.name ?? '—',
                mobileSubtitle: (p) => '${p.receiptNo} · ${Fmt.date(p.date)}',
                mobileTrailing: (context, p) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    Fmt.money(p.amount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                      fontFeatures: kTabular,
                    ),
                  ),
                ),
                columns: [
                  TableCol<Payment>(
                    label: S.receiptNo,
                    minWidth: 115,
                    text: (p) => p.receiptNo,
                    cell: (context, p) => Text(
                      p.receiptNo,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  TableCol<Payment>(
                    label: S.memberName,
                    flex: 2,
                    minWidth: 175,
                    showOnMobile: false,
                    text: (p) => members[p.memberId]?.name ?? '—',
                    cell: (context, p) {
                      final m = members[p.memberId];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m?.name ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (m != null)
                            Text(
                              m.regNo,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.colors.textMuted,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  TableCol<Payment>(
                    label: 'Type',
                    minWidth: 125,
                    hideBelow: ScreenSize.desktop,
                    text: (p) => p.kind.label,
                    cell: (context, p) => Text(p.kind.label),
                  ),
                  TableCol<Payment>(
                    label: S.date,
                    minWidth: 110,
                    showOnMobile: false,
                    text: (p) => Fmt.date(p.date),
                    cell: (context, p) => Text(Fmt.date(p.date)),
                  ),
                  TableCol<Payment>(
                    label: S.mode,
                    minWidth: 105,
                    hideBelow: ScreenSize.laptop,
                    text: (p) => p.mode.label,
                    cell: (context, p) => Text(p.mode.label),
                  ),
                  TableCol<Payment>(
                    label: S.agent,
                    minWidth: 135,
                    hideBelow: ScreenSize.desktop,
                    text: (p) => agents[p.agentId]?.name ?? '—',
                    cell: (context, p) => Text(
                      agents[p.agentId]?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TableCol<Payment>(
                    label: S.status,
                    minWidth: 100,
                    cell: (context, p) => PaymentStatusPill(status: p.status),
                  ),
                  TableCol<Payment>(
                    label: S.amount,
                    minWidth: 110,
                    numeric: true,
                    showOnMobile: false,
                    text: (p) => Fmt.money(p.amount),
                    cell: (context, p) => Text(
                      Fmt.money(p.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                rowActions: (context, p) =>
                    _PaymentActions(payment: p, member: members[p.memberId]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PaymentFilters extends ConsumerWidget {
  const _PaymentFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(paymentFilterProvider);
    final notifier = ref.read(paymentFilterProvider.notifier);

    return FilterBar(
      search: SearchField(
        hint: 'Receipt, member, reg no…',
        onChanged: notifier.setQuery,
      ),
      filters: [
        FilterMenu<PaymentStatus>(
          label: S.status,
          value: filter.status,
          items: PaymentStatus.values,
          itemLabel: (s) => s.label,
          onChanged: notifier.setStatus,
        ),
        FilterMenu<PaymentMode>(
          label: S.mode,
          value: filter.mode,
          items: PaymentMode.values,
          itemLabel: (m) => m.label,
          onChanged: notifier.setMode,
        ),
        FilterMenu<PaymentKind>(
          label: 'Type',
          value: filter.kind,
          items: PaymentKind.values,
          itemLabel: (k) => k.label,
          onChanged: notifier.setKind,
        ),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(DateTime.now().year + 1),
              initialDateRange: filter.from != null && filter.to != null
                  ? DateTimeRange(start: filter.from!, end: filter.to!)
                  : null,
            );
            if (range != null) notifier.setRange(range.start, range.end);
          },
          child: FilterButtonFrame(
            active: filter.from != null,
            icon: Icons.calendar_today_outlined,
            child: Text(
              filter.from == null
                  ? S.date
                  : '${Fmt.dateShort(filter.from)} – ${Fmt.dateShort(filter.to)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onClear: filter.isEmpty ? null : notifier.clear,
    );
  }
}

class _PaymentActions extends ConsumerWidget {
  const _PaymentActions({required this.payment, this.member});

  final Payment payment;
  final MemberRef? member;

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
            _showReceipt(context, ref, payment, member);
          case 1:
            showPaymentFormDialog(context, existing: payment);
          case 2:
            await runWithToast(
              context,
              () => ref
                  .read(paymentActionsProvider)
                  .edit(payment.copyWith(status: PaymentStatus.paid)),
              success: 'Marked as paid',
            );
          case 3:
            final ok = await confirmDialog(context);
            if (!ok || !context.mounted) return;
            await runWithToast(
              context,
              () => ref.read(paymentActionsProvider).remove(payment.id),
              success: 'Payment removed',
            );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('View receipt')),
        const PopupMenuItem(value: 1, child: Text(S.edit)),
        if (payment.status != PaymentStatus.paid)
          const PopupMenuItem(value: 2, child: Text(S.markPaid)),
        PopupMenuItem(
          value: 3,
          child: Text(S.delete, style: TextStyle(color: c.danger)),
        ),
      ],
    );
  }
}

void _showReceipt(
  BuildContext context,
  WidgetRef ref,
  Payment p,
  MemberRef? member,
) {
  final yojna = ref.read(yojnaByIdProvider)[p.yojnaId];
  final agent = ref.read(agentByIdProvider)[p.agentId];

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: p.receiptNo,
      subtitle: Fmt.dateTime(p.date),
      maxWidth: 520,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  Fmt.money(p.amount),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontFeatures: kTabular,
                  ),
                ),
              ),
              PaymentStatusPill(status: p.status),
            ],
          ),
          const SizedBox(height: 12),
          DetailRow(label: S.memberName, value: member?.name ?? '—'),
          DetailRow(label: S.regNo, value: member?.regNo ?? '—'),
          DetailRow(label: S.scheme, value: yojna?.name ?? '—'),
          DetailRow(label: 'Type', value: p.kind.label),
          DetailRow(label: S.mode, value: p.mode.label),
          DetailRow(label: S.date, value: Fmt.date(p.date)),
          DetailRow(label: 'Collected by', value: agent?.name ?? '—'),
          if (p.reference.isNotEmpty)
            DetailRow(label: 'Reference', value: p.reference),
          if (p.note.isNotEmpty) DetailRow(label: 'Note', value: p.note),
        ],
      ),
    ),
  );
}
