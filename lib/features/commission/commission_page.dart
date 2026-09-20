import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/responsive_table.dart';
import '../../widgets/stat_card.dart';

/// What each agent earned in one month (IMPLEMENTATION_PLAN Phase 16).
///
/// The numbers are recalculated on every read, so a receipt cancelled later
/// moves them. Only an owner marks a month paid (§11.3); staff read it.
class CommissionPage extends ConsumerWidget {
  const CommissionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commissionReportProvider);
    final rows = async.value;
    final month = ref.watch(commissionMonthProvider);
    final isOwner = ref.watch(currentUserProvider).isOwner;

    final owed = rows?.fold<double>(0, (sum, r) => sum + r.amount) ?? 0;
    final paid = rows?.fold<double>(0, (sum, r) => sum + (r.paidAmount ?? 0)) ?? 0;
    final unpaid = rows?.where((r) => !r.isPaid).length ?? 0;

    return PageBody(
      maxWidth: 1040,
      children: [
        const SectionHeader(title: S.commission, subtitle: S.commissionSub),
        const SizedBox(height: Space.lg),
        const _MonthSwitcher(),
        const SizedBox(height: Space.lg),
        StatGrid(
          children: [
            StatCard(
              label: 'Commission owed',
              value: Fmt.money(owed),
              icon: Icons.percent_rounded,
              accent: StatAccent.blue,
              caption: Fmt.month(month),
            ),
            StatCard(
              label: S.commissionPaid,
              value: Fmt.money(paid),
              icon: Icons.check_circle_outline,
              accent: StatAccent.green,
            ),
            StatCard(
              label: S.commissionUnpaid,
              value: Fmt.number(unpaid),
              icon: Icons.hourglass_top_rounded,
              accent: StatAccent.amber,
              caption: unpaid == 1 ? 'agent' : 'agents',
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        AppCard(
          child: async.hasError && rows == null
              ? ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(commissionReportProvider),
                )
              : rows == null
                  ? const LoadingState()
                  : ResponsiveTable<CommissionMonth>(
                      rows: rows,
                      paginate: false,
                      busy: async.isLoading,
                      emptyMessage: 'No agents yet.',
                      rowKey: (r) => r.agentId,
                      mobileTitle: (r) => r.agentName,
                      mobileSubtitle: (r) =>
                          '${Fmt.money(r.collected)} collected · '
                          '${Fmt.money(r.amount)} at ${r.percent}%',
                      mobileTrailing: (context, r) => _PaidPill(row: r),
                      columns: [
                        TableCol<CommissionMonth>(
                          label: S.agent,
                          flex: 2,
                          minWidth: 170,
                          text: (r) => r.agentName,
                          cell: (context, r) => Text(
                            r.agentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TableCol<CommissionMonth>(
                          label: S.code,
                          minWidth: 90,
                          hideBelow: ScreenSize.desktop,
                          text: (r) => r.agentCode,
                          cell: (context, r) => Text(r.agentCode),
                        ),
                        TableCol<CommissionMonth>(
                          label: S.collectedInMonth,
                          minWidth: 110,
                          numeric: true,
                          text: (r) => Fmt.money(r.collected),
                          cell: (context, r) => Text(Fmt.money(r.collected)),
                        ),
                        TableCol<CommissionMonth>(
                          label: '%',
                          minWidth: 70,
                          numeric: true,
                          hideBelow: ScreenSize.desktop,
                          text: (r) => '${r.percent}%',
                          cell: (context, r) => Text('${r.percent}%'),
                        ),
                        TableCol<CommissionMonth>(
                          label: S.commission,
                          minWidth: 110,
                          numeric: true,
                          text: (r) => Fmt.money(r.amount),
                          cell: (context, r) => Text(
                            Fmt.money(r.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TableCol<CommissionMonth>(
                          label: S.status,
                          minWidth: 150,
                          showOnMobile: false,
                          cell: (context, r) => _PaidPill(row: r),
                        ),
                      ],
                      rowActions: !isOwner
                          ? null
                          : (context, r) => TextButton(
                                onPressed: () =>
                                    showCommissionPaidDialog(context, r),
                                child: Text(
                                  r.isPaid ? S.edit : S.markCommissionPaid,
                                ),
                              ),
                    ),
        ),
        if (!isOwner) ...[
          const SizedBox(height: Space.md),
          Text(
            S.ownerOnlyCommission,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// One month back or forward. The office never pays a month that has not
/// started, so forward stops at the current one.
class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final month = ref.watch(commissionMonthProvider);
    final notifier = ref.read(commissionMonthProvider.notifier);
    final now = DateTime.now();
    final atLatest = !month.isBefore(DateTime(now.year, now.month));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => notifier.shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
        ),
        SizedBox(
          width: 130,
          child: Text(
            Fmt.month(month),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: atLatest ? null : () => notifier.shift(1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

class _PaidPill extends StatelessWidget {
  const _PaidPill({required this.row});

  final CommissionMonth row;

  @override
  Widget build(BuildContext context) {
    if (!row.isPaid) {
      return const StatusPill(S.commissionUnpaid, tone: PillTone.warning);
    }
    // A difference means the collections moved after the month was paid.
    return StatusPill(
      row.differs
          ? '${S.commissionPaid} ${Fmt.money(row.paidAmount)}'
          : S.commissionPaid,
      tone: row.differs ? PillTone.info : PillTone.success,
    );
  }
}

/// Owners only. An empty amount pays the calculated commission; paying a month
/// that was already paid corrects it.
void showCommissionPaidDialog(BuildContext context, CommissionMonth row) {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(
    text: (row.paidAmount ?? row.amount).toStringAsFixed(0),
  );
  final reference = TextEditingController(text: row.reference);

  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: S.markCommissionPaid,
      subtitle: '${row.agentName} · ${Fmt.month(row.month)}',
      maxWidth: 460,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(S.cancel),
        ),
        Consumer(
          builder: (context, ref, _) => FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop();
              await runWithToast(
                context,
                () => ref.read(commissionActionsProvider).markPaid(
                      agentId: row.agentId,
                      month: row.month,
                      amount: double.parse(amount.text.trim()),
                      reference: reference.text.trim(),
                    ),
                success: 'Commission marked paid',
              );
            },
            child: const Text(S.save),
          ),
        ),
      ],
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailRow(
              label: S.collectedInMonth,
              value: Fmt.money(row.collected),
            ),
            DetailRow(label: S.commission, value: '${row.percent}%'),
            DetailRow(label: 'Calculated', value: Fmt.money(row.amount)),
            const SizedBox(height: Space.lg),
            AppTextField(
              label: S.amountPaid,
              controller: amount,
              required: true,
              keyboardType: TextInputType.number,
              validator: V.amount,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.commissionReference,
              controller: reference,
              hint: 'UPI reference, cheque number or "cash"',
            ),
          ],
        ),
      ),
    ),
  );
}
