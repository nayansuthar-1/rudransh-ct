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
    final async = ref.watch(paymentsProvider);
    final payments = ref.watch(filteredPaymentsProvider);
    final totals = ref.watch(paymentTotalsProvider);
    final members = ref.watch(memberByIdProvider);
    final agents = ref.watch(agentByIdProvider);
    final yojna = ref.watch(selectedYojnaProvider);

    return PageBody(
      children: [
        SectionHeader(
          title: S.payments,
          subtitle: yojna?.name ?? 'सभी योजनाएँ',
          actions: [
            FilledButton.icon(
              onPressed: () => showPaymentFormDialog(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text(S.addPayment),
            ),
          ],
        ),
        const SizedBox(height: 18),
        StatGrid(
          children: [
            StatCard(
              label: 'Transactions',
              value: Fmt.number(totals.count),
              icon: Icons.receipt_long_outlined,
            ),
            StatCard(
              label: 'Paid',
              value: Fmt.moneyCompact(totals.paid),
              icon: Icons.check_circle_outline,
              tone: PillTone.success,
            ),
            StatCard(
              label: 'Pending',
              value: Fmt.moneyCompact(totals.pending),
              icon: Icons.schedule_rounded,
              tone: PillTone.warning,
            ),
            StatCard(
              label: 'Failed',
              value: Fmt.moneyCompact(totals.failed),
              icon: Icons.highlight_off_rounded,
              tone: PillTone.danger,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _PaymentFilters(),
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
                  onRetry: () => ref.invalidate(paymentsProvider),
                );
              }
              return ResponsiveTable<Payment>(
                rows: payments,
                pageSize: 14,
                mobileTitle: (p) => members[p.memberId]?.name ?? '—',
                mobileSubtitle: (p) => '${p.receiptNo} · ${Fmt.date(p.date)}',
                columns: [
                  TableCol<Payment>(
                    label: S.receiptNo,
                    minWidth: 115,
                    text: (p) => p.receiptNo,
                    cell: (context, p) => Text(
                      p.receiptNo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TableCol<Payment>(
                    label: S.memberName,
                    flex: 2,
                    minWidth: 175,
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
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (m != null)
                            Text(
                              m.regNo,
                              style: TextStyle(
                                fontSize: 11.5,
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
                    cell: (context, p) =>
                        Text(p.kind.label, style: const TextStyle(fontSize: 12.5)),
                  ),
                  TableCol<Payment>(
                    label: S.date,
                    minWidth: 110,
                    text: (p) => Fmt.date(p.date),
                    cell: (context, p) =>
                        Text(Fmt.date(p.date), style: const TextStyle(fontSize: 13)),
                  ),
                  TableCol<Payment>(
                    label: S.mode,
                    minWidth: 105,
                    hideBelow: ScreenSize.laptop,
                    text: (p) => p.mode.label,
                    cell: (context, p) =>
                        Text(p.mode.label, style: const TextStyle(fontSize: 13)),
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
                      style: const TextStyle(fontSize: 12.5),
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
                    text: (p) => Fmt.money(p.amount),
                    cell: (context, p) => Text(
                      Fmt.money(p.amount),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                rowActions: (context, p) => _PaymentActions(payment: p),
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

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          FormGrid(
            gap: 12,
            columnsOverride:
                context.responsive<int>(mobile: 1, tablet: 2, laptop: 4),
            items: [
              GridItem(
                SearchField(
                  hint: 'Receipt, सदस्य, Reg No…',
                  onChanged: notifier.setQuery,
                ),
              ),
              GridItem(
                AppDropdown<PaymentStatus>(
                  label: '',
                  value: filter.status,
                  items: PaymentStatus.values,
                  itemLabel: (s) => s.label,
                  includeAllOption: true,
                  allLabel: 'All statuses',
                  hint: 'All statuses',
                  onChanged: notifier.setStatus,
                ),
              ),
              GridItem(
                AppDropdown<PaymentMode>(
                  label: '',
                  value: filter.mode,
                  items: PaymentMode.values,
                  itemLabel: (m) => m.label,
                  includeAllOption: true,
                  allLabel: 'All modes',
                  hint: 'All modes',
                  onChanged: notifier.setMode,
                ),
              ),
              GridItem(
                AppDropdown<PaymentKind>(
                  label: '',
                  value: filter.kind,
                  items: PaymentKind.values,
                  itemLabel: (k) => k.label,
                  includeAllOption: true,
                  allLabel: 'All types',
                  hint: 'All types',
                  onChanged: notifier.setKind,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(DateTime.now().year + 1),
                      initialDateRange: filter.from != null && filter.to != null
                          ? DateTimeRange(start: filter.from!, end: filter.to!)
                          : null,
                    );
                    if (range != null) {
                      notifier.setRange(range.start, range.end);
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined, size: 16),
                  label: Text(
                    filter.from == null
                        ? 'Any date'
                        : '${Fmt.dateShort(filter.from)} → ${Fmt.dateShort(filter.to)}',
                  ),
                ),
              ),
              if (!filter.isEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: notifier.clear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text(S.clearFilters),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentActions extends ConsumerWidget {
  const _PaymentActions({required this.payment});

  final Payment payment;

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
            _showReceipt(context, ref, payment);
          case 1:
            showPaymentFormDialog(context, existing: payment);
          case 2:
            await ref
                .read(paymentsProvider.notifier)
                .edit(payment.copyWith(status: PaymentStatus.paid));
            if (context.mounted) showToast(context, 'Marked as paid');
          case 3:
            final ok = await confirmDialog(context);
            if (!ok) return;
            await ref.read(paymentsProvider.notifier).remove(payment.id);
            if (context.mounted) showToast(context, 'Payment removed');
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

void _showReceipt(BuildContext context, WidgetRef ref, Payment p) {
  final member = ref.read(memberByIdProvider)[p.memberId];
  final yojna = ref.read(yojnaByIdProvider)[p.yojnaId];
  final agent = ref.read(agentByIdProvider)[p.agentId];

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: p.receiptNo,
      subtitle: Fmt.dateTime(p.date),
      icon: Icons.receipt_long_outlined,
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
          Center(
            child: Column(
              children: [
                Text(
                  Fmt.money(p.amount),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                PaymentStatusPill(status: p.status),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
