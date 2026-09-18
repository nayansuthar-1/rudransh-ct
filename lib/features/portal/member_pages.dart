import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// What the member owes, and how to pay it (IMPLEMENTATION_PLAN Phase 15).
class MemberDuesPage extends ConsumerWidget {
  const MemberDuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myDuesProvider);
    final dues = async.value;

    return PageBody(
      maxWidth: 720,
      children: [
        const SectionHeader(title: S.myDues, subtitle: S.myDuesSub),
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
          const AppCard(
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              message: S.nothingOwed,
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

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Closing ${due.closingGroup}',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                due.state.label,
                tone: waiting ? PillTone.warning : PillTone.danger,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          DetailRow(label: 'Closing date', value: Fmt.date(due.closingDate)),
          DetailRow(label: 'Amount', value: Fmt.money(due.amount)),
          if (waiting)
            DetailRow(
              label: 'Waiting for approval',
              value: Fmt.money(due.pending),
            ),
          const SizedBox(height: Space.md),
          if (waiting)
            Text(
              S.upiSentForApproval,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            )
          else if (Env.hasUpi)
            FilledButton.icon(
              onPressed: () => showUpiDialog(
                context,
                amount: due.amount,
                closingCaseId: due.closingCaseId,
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text(S.payByUpi),
            )
          else
            Text(
              'Pay your agent or the office. '
              'Online payment is not switched on yet.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// The member's receipts.
class MemberPaymentsPage extends ConsumerWidget {
  const MemberPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPaymentsProvider);
    final items = async.value;

    return PageBody(
      maxWidth: 720,
      children: [
        const SectionHeader(title: S.myPayments, subtitle: S.myPaymentsSub),
        const SizedBox(height: Space.xl),
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
          const AppCard(
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No receipts yet.',
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow(this.payment);

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final cancelled = payment.isCancelled;

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
                  '${Fmt.date(payment.date)} · ${payment.kind.label}',
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
                cancelled ? 'Cancelled' : payment.status.label,
                tone: switch (payment.status) {
                  PaymentStatus.paid => PillTone.success,
                  PaymentStatus.pending => PillTone.warning,
                  PaymentStatus.failed => PillTone.danger,
                },
              ),
            ],
          ),
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

    return AppDialog(
      title: S.payByUpi,
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const ButtonSpinner() : const Text(S.save),
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
                    'Pay to',
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
              'Pay in your UPI app first, then enter the reference below.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.upiAmount,
              controller: _amount,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                return n == null || n <= 0 ? 'Enter the amount you paid.' : null;
              },
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.upiReference,
              controller: _reference,
              hint: S.upiReferenceHint,
              required: true,
              validator: (v) => (v ?? '').trim().length < 6
                  ? 'Enter the UPI reference (UTR) from your payment app.'
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
    return AppDialog(
      title: S.requestCorrection,
      subtitle: S.requestCorrectionSub,
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const ButtonSpinner() : const Text(S.save),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<ChangeField>(
              label: S.whatToChange,
              value: _field,
              items: ChangeField.values,
              itemLabel: (f) => f.label,
              required: true,
              onChanged: (f) => setState(() => _field = f ?? _field),
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.newValue,
              controller: _value,
              required: true,
              autofocus: true,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the new value.' : null,
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
