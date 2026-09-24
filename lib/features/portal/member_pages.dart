import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/trust_repository.dart' show RepositoryException;
import '../../state/member_lang.dart';
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../receipt/receipt_action.dart';
import 'razorpay_checkout.dart';

/// What the member owes, and how to pay it (IMPLEMENTATION_PLAN Phase 15).
class MemberDuesPage extends ConsumerWidget {
  const MemberDuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myDuesProvider);
    final dues = async.value;
    final t = ref.watch(memberTextProvider);

    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(title: t.navDues, subtitle: t.navDuesSub),
        const SizedBox(height: Space.xl),
        if (dues == null && async.hasError)
          AppCard(
            child: ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(myDuesProvider),
            ),
          )
        else if (dues == null)
          const AppCard(child: LoadingState())
        else if (dues.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              message: t.nothingOwed,
            ),
          )
        else
          for (final d in dues) ...[
            _DueCard(d),
            const SizedBox(height: Space.md),
          ],
      ],
    );
  }
}

class _DueCard extends ConsumerWidget {
  const _DueCard(this.due);

  final MemberDue due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final waiting = due.pending > 0;
    final t = ref.watch(memberTextProvider);

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.closing(due.closingGroup),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                t.dueState(due.state),
                tone: waiting ? PillTone.warning : PillTone.danger,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          DetailRow(label: t.closingDate, value: Fmt.date(due.closingDate)),
          DetailRow(label: t.amount, value: Fmt.money(due.amount)),
          if (waiting)
            DetailRow(
              label: t.waitingForApproval,
              value: Fmt.money(due.pending),
            ),
          const SizedBox(height: Space.md),
          if (waiting)
            Text(
              t.sentForApproval,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            )
          else if (Env.hasRazorpay || Env.hasUpi)
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (Env.hasRazorpay)
                  FilledButton.icon(
                    onPressed: () => _payOnline(context, ref, due),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(t.payOnline),
                  ),
                if (Env.hasUpi)
                  (Env.hasRazorpay ? OutlinedButton.icon : FilledButton.icon)(
                    onPressed: () => showUpiDialog(
                      context,
                      amount: due.amount,
                      closingCaseId: due.closingCaseId,
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: Text(t.payByUpi),
                  ),
              ],
            )
          else
            Text(
              t.payOffline,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// Razorpay checkout for one due. Paid is final: Razorpay has confirmed the
/// money and the server checked its signature, so no office approval.
Future<void> _payOnline(
  BuildContext context,
  WidgetRef ref,
  MemberDue due,
) async {
  final t = ref.read(memberTextProvider);
  try {
    final receipt = await ref.read(portalActionsProvider).payOnline(
      due.closingCaseId,
      checkout: (order) async {
        final r = await openRazorpayCheckout(order);
        return r == null
            ? null
            : (
                orderId: r.orderId,
                paymentId: r.paymentId,
                signature: r.signature,
              );
      },
    );
    if (receipt != null && context.mounted) {
      showToast(context, t.paidOnline(receipt));
    }
  } catch (e) {
    if (context.mounted) {
      showToast(
        context,
        e is RepositoryException ? e.message : '$e',
        error: true,
      );
    }
  }
}

/// The member's receipts.
class MemberPaymentsPage extends ConsumerWidget {
  const MemberPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPaymentsProvider);
    final items = async.value;
    final t = ref.watch(memberTextProvider);

    return PageBody(
      maxWidth: 720,
      children: [
        SectionHeader(title: t.navPayments, subtitle: t.navPaymentsSub),
        const SizedBox(height: Space.xl),
        if (items != null && items.isNotEmpty) ...[
          Builder(builder: (context) {
            final totalPaid = items
                .where((p) => p.status == PaymentStatus.paid)
                .fold<double>(0, (sum, p) => sum + p.amount);
            final paidCount =
                items.where((p) => p.status == PaymentStatus.paid).length;
            final text = Theme.of(context).textTheme;
            return AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.totalContributed,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Fmt.money(totalPaid),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: context.colors.border,
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.approvedReceipts,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.issued(paidCount),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: Space.md),
        ],
        if (items == null && async.hasError)
          AppCard(
            child: ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(myPaymentsProvider),
            ),
          )
        else if (items == null)
          const AppCard(child: LoadingState())
        else if (items.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              message: t.noReceipts,
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (final (i, p) in items.indexed) ...[
                  if (i > 0)
                    Divider(height: 1, color: context.colors.border),
                  _PaymentRow(p),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow(this.payment);

  final Payment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final cancelled = payment.isCancelled;
    final t = ref.watch(memberTextProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.receiptNo.isEmpty ? '—' : payment.receiptNo,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${Fmt.date(payment.date)} · ${t.paymentKind(payment.kind)}',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
                if (payment.rejectReason.isNotEmpty)
                  Text(
                    payment.rejectReason,
                    style: text.bodySmall?.copyWith(color: c.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(payment.amount),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              StatusPill(
                t.paymentStatus(payment),
                tone: switch (payment.status) {
                  PaymentStatus.paid => PillTone.success,
                  PaymentStatus.pending => PillTone.warning,
                  PaymentStatus.failed => PillTone.danger,
                },
              ),
            ],
          ),
          if (!cancelled && payment.receiptNo.isNotEmpty) ...[
            const SizedBox(width: Space.sm),
            IconButton(
              icon: const Icon(Icons.print_outlined, size: 20),
              tooltip: t.printReceipt,
              onPressed: () {
                final membership = ref.read(myMembershipProvider).value;
                printPaymentReceipt(
                  context,
                  payment: payment,
                  member: membership?.toMember(),
                  yojnaName: membership?.yojnaName ?? '',
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paying by UPI
// ---------------------------------------------------------------------------

/// The member pays in their own UPI app, then enters the reference here. The
/// office approves it, so nothing counts until they have seen the money.
Future<void> showUpiDialog(
  BuildContext context, {
  required double amount,
  String? closingCaseId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _UpiDialog(amount: amount, closingCaseId: closingCaseId),
    );

class _UpiDialog extends ConsumerStatefulWidget {
  const _UpiDialog({required this.amount, this.closingCaseId});

  final double amount;
  final String? closingCaseId;

  @override
  ConsumerState<_UpiDialog> createState() => _UpiDialogState();
}

class _UpiDialogState extends ConsumerState<_UpiDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  late final _amount =
      TextEditingController(text: widget.amount.toStringAsFixed(0));

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(portalActionsProvider).payByUpi(
            amount: double.parse(_amount.text),
            reference: _reference.text,
            closingCaseId: widget.closingCaseId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ref.watch(memberTextProvider);

    return AppDialog(
      title: t.payByUpi,
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const ButtonSpinner() : Text(t.send),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.payTo,
                    style: TextStyle(fontSize: 12, color: c.onBrandSoft),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    Env.upiId,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.onBrandSoft,
                    ),
                  ),
                  if (Env.upiPayee.isNotEmpty)
                    Text(
                      Env.upiPayee,
                      style: TextStyle(fontSize: 13, color: c.onBrandSoft),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            Text(
              t.payFirst,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: t.amountPaid,
              controller: _amount,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                return n == null || n <= 0 ? t.enterAmount : null;
              },
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: t.upiReference,
              controller: _reference,
              hint: t.upiReferenceHint,
              required: true,
              validator: (v) => (v ?? '').trim().length < 6
                  ? t.enterUtr
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(
                _error!,
                style: TextStyle(color: c.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asking for a correction
// ---------------------------------------------------------------------------

Future<void> showCorrectionDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _CorrectionDialog(),
    );

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog();

  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();

  ChangeField _field = ChangeField.primaryPhone;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(portalActionsProvider).requestChange(_field, _value.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(memberTextProvider);
    return AppDialog(
      title: t.requestCorrection,
      subtitle: t.requestCorrectionSub,
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const ButtonSpinner() : Text(t.send),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<ChangeField>(
              label: t.whatToChange,
              value: _field,
              items: ChangeField.values,
              itemLabel: t.changeField,
              required: true,
              onChanged: (f) => setState(() => _field = f ?? _field),
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: t.newValue,
              controller: _value,
              required: true,
              autofocus: true,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? t.enterNewValue : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(
                _error!,
                style: TextStyle(color: context.colors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
