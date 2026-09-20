import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/agent_repository.dart';
import '../../state/agent_providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// Cash the agent still holds, past handovers and monthly commission
/// (IMPLEMENTATION_PLAN Phase 16).
///
/// Only approved cash counts: the office approves an agent's receipts first,
/// so a rejected receipt can never end up inside a declared handover. UPI and
/// bank payments never reach the agent's hand at all.
class AgentCashSection extends ConsumerWidget {
  const AgentCashSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final summary = ref.watch(agentSummaryProvider).value ?? AgentSummary.empty;
    final handovers = ref.watch(agentHandoversProvider).value ?? const [];
    final months = ref.watch(agentCommissionProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: S.cashInHand,
          subtitle: S.cashInHandSub,
          dense: true,
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.lg,
                  runSpacing: Space.md,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Fmt.money(summary.cashInHand),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          summary.handoverWaiting > 0
                              ? '${Fmt.money(summary.handoverWaiting)} '
                                  '${S.handoverWaiting.toLowerCase()}'
                              : S.cashInHandSub,
                          style:
                              TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: summary.cashInHand <= 0
                          ? null
                          : () => showHandoverDialog(context),
                      icon: const Icon(Icons.savings_outlined, size: 17),
                      label: const Text(S.handover),
                    ),
                  ],
                ),
              ),
              for (final h in handovers.take(4)) ...[
                Divider(height: 1, color: c.border),
                _HandoverTile(handover: h),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(
          title: S.myCommission,
          subtitle: 'Your share of what you collected, month by month',
          dense: true,
        ),
        const SizedBox(height: Space.md),
        AppCard(
          child: months.isEmpty
              ? const EmptyState(
                  message: 'Nothing collected yet.',
                  icon: Icons.percent_rounded,
                )
              : Column(
                  children: [
                    for (final (i, m) in months.indexed) ...[
                      if (i > 0) Divider(height: 1, color: c.border),
                      _CommissionTile(month: m),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _HandoverTile extends StatelessWidget {
  const _HandoverTile({required this.handover});

  final CashHandover handover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = handover;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 2),
      title: Text(
        '${Fmt.money(h.amount)} · ${h.receiptCount} '
        '${h.receiptCount == 1 ? 'receipt' : 'receipts'}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        h.status == RequestStatus.rejected && h.decisionNote.isNotEmpty
            ? '${Fmt.date(h.declaredAt)} · ${h.decisionNote}'
            : Fmt.date(h.declaredAt),
        style: TextStyle(fontSize: 13, color: c.textSecondary),
      ),
      trailing: StatusPill(
        switch (h.status) {
          RequestStatus.pending => S.handoverWaiting,
          RequestStatus.approved => 'Received',
          RequestStatus.rejected => 'Not received',
        },
        tone: switch (h.status) {
          RequestStatus.pending => PillTone.warning,
          RequestStatus.approved => PillTone.success,
          RequestStatus.rejected => PillTone.danger,
        },
      ),
    );
  }
}

class _CommissionTile extends StatelessWidget {
  const _CommissionTile({required this.month});

  final CommissionMonth month;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = month;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 2),
      title: Text(
        Fmt.month(m.month),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${Fmt.money(m.collected)} collected · ${m.percent}%',
        style: TextStyle(fontSize: 13, color: c.textSecondary),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Fmt.money(m.amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          Text(
            m.isPaid ? '${S.commissionPaid} ${Fmt.date(m.paidAt)}' : S.commissionUnpaid,
            style: TextStyle(
              fontSize: 12,
              color: m.isPaid ? c.success : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks which receipts go with the cash. Everything is ticked to start with,
/// because handing over the lot is the usual case.
void showHandoverDialog(BuildContext context) {
  AppDialog.show<void>(
    context: context,
    builder: (dialogContext) => const _HandoverDialog(),
  );
}

class _HandoverDialog extends ConsumerStatefulWidget {
  const _HandoverDialog();

  @override
  ConsumerState<_HandoverDialog> createState() => _HandoverDialogState();
}

class _HandoverDialogState extends ConsumerState<_HandoverDialog> {
  final _note = TextEditingController();

  /// Null until the receipts have loaded, then every id, minus what is
  /// unticked.
  Set<String>? _chosen;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(agentOpenCashProvider);
    final receipts = async.value;
    final chosen = _chosen ??= {for (final r in receipts ?? const []) r.id};
    final total = (receipts ?? const <OpenCashReceipt>[])
        .where((r) => chosen.contains(r.id))
        .fold<double>(0, (sum, r) => sum + r.amount);

    return AppDialog(
      title: S.handover,
      subtitle: 'The office confirms it once they have the money',
      maxWidth: 560,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: chosen.isEmpty || _saving ? null : _submit,
          child: const Text(S.declareHandover),
        ),
      ],
      child: receipts == null
          ? (async.hasError
              ? ErrorStateView(
                  error: async.error!,
                  onRetry: () => ref.invalidate(agentOpenCashProvider),
                )
              : const LoadingState())
          : receipts.isEmpty
              ? const EmptyState(
                  message: S.noOpenCash,
                  icon: Icons.savings_outlined,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${chosen.length} of ${receipts.length} receipts · '
                      '${Fmt.money(total)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    for (final r in receipts)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: chosen.contains(r.id),
                        onChanged: _saving
                            ? null
                            : (on) => setState(() {
                                  if (on ?? false) {
                                    chosen.add(r.id);
                                  } else {
                                    chosen.remove(r.id);
                                  }
                                }),
                        title: Text(
                          '${r.receiptNo} · ${Fmt.money(r.amount)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          [r.memberName, r.memberRegNo, Fmt.date(r.date)]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style:
                              TextStyle(fontSize: 12.5, color: c.textSecondary),
                        ),
                      ),
                    const SizedBox(height: Space.md),
                    AppTextField(
                      label: S.handoverNote,
                      controller: _note,
                      hint: 'Optional — who you handed it to, for example',
                    ),
                  ],
                ),
    );
  }

  Future<void> _submit() async {
    final chosen = _chosen ?? const <String>{};
    final all = ref.read(agentOpenCashProvider).value ?? const [];
    setState(() => _saving = true);
    // Every receipt ticked means "all of it", which the database reads as null.
    final ids = chosen.length == all.length ? const <String>[] : chosen.toList();
    try {
      await ref
          .read(agentActionsProvider)
          .declareHandover(paymentIds: ids, note: _note.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, S.handoverDeclared);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '$e', error: true);
    }
  }
}
