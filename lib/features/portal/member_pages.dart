import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/env.dart';
import '../../core/router/routes.dart';
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
import '../../widgets/stat_card.dart';
import 'member_widgets.dart';
import 'razorpay_checkout.dart';

/// What the member owes, and how to pay it (IMPLEMENTATION_PLAN Phase 15).
class MemberDuesPage extends ConsumerWidget {
  const MemberDuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myDuesProvider);
    final dues = async.value;
    final t = ref.watch(memberTextProvider);
    final c = context.colors;

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
          const _AllPaid()
        else ...[
          _DueSummary(dues),
          const SizedBox(height: Space.xl),
          for (final (i, d) in dues.indexed) ...[
            _DueCard(d, oldest: i == 0 && dues.length > 1),
            const SizedBox(height: Space.md),
          ],
          const SizedBox(height: Space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  t.receiptHint,
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Nothing owed: say thank you, and point at the receipts.
class _AllPaid extends ConsumerWidget {
  const _AllPaid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = ref.watch(memberTextProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.xxl,
      ),
      decoration: BoxDecoration(
        color: accentBackground(context, StatAccent.green),
        borderRadius: BorderRadius.circular(Radii.dialog),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: StatAccent.green.color,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            t.allPaidTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            t.nothingOwed,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
          const SizedBox(height: Space.xs),
          Text(
            t.allPaidSub,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.memberPayments),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(t.navPayments),
          ),
        ],
      ),
    );
  }
}

/// The total owed, large, above the closings that make it up.
class _DueSummary extends ConsumerWidget {
  const _DueSummary(this.dues);

  final List<MemberDue> dues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = ref.watch(memberTextProvider);
    final open = dues.where((d) => d.due > 0 && d.pending <= 0).toList();
    final owed = open.fold<double>(0, (s, d) => s + d.due);
    final waiting = dues.fold<double>(0, (s, d) => s + d.pending);
    final accent = owed > 0 ? StatAccent.amber : StatAccent.blue;

    return Container(
      padding: const EdgeInsets.all(Space.xl - 4),
      decoration: BoxDecoration(
        color: accentBackground(context, accent),
        borderRadius: BorderRadius.circular(Radii.dialog),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.totalDue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.xs),
                CountUp(
                  value: owed,
                  builder: (_, v) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Fmt.money(v.round()),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  open.isEmpty
                      ? t.pendingSub
                      : '${t.closingsLeft(open.length)} · '
                          '${t.eachClosing(open.first.amount)}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                if (waiting > 0 && open.isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  StatusPill(t.pendingTitle(waiting), tone: PillTone.info),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              owed > 0
                  ? Icons.account_balance_wallet_outlined
                  : Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _DueCard extends ConsumerWidget {
  const _DueCard(this.due, {this.oldest = false});

  final MemberDue due;

  /// The first of several: the one to pay first.
  final bool oldest;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateTile(
                due.closingDate,
                accent: waiting ? StatAccent.blue : StatAccent.amber,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.closing(due.closingGroup),
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.closingDate}: ${Fmt.date(due.closingDate)}',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    if (oldest) ...[
                      const SizedBox(height: Space.xs),
                      StatusPill(t.oldestFirst, tone: PillTone.danger),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.money(waiting ? due.pending : due.due),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  StatusPill(
                    t.dueState(due.state),
                    tone: waiting ? PillTone.warning : PillTone.danger,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (waiting)
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, size: 16, color: c.info),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    t.sentForApproval,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
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
                      amount: due.due,
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

/// A calendar leaf: the day large, month and year under it.
class _DateTile extends StatelessWidget {
  const _DateTile(this.date, {required this.accent});

  final DateTime date;
  final StatAccent accent;

  static final _monthYear = DateFormat('MMM yy');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      decoration: BoxDecoration(
        color: accentBackground(context, accent),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Column(
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent.color,
              height: 1.1,
            ),
          ),
          Text(
            _monthYear.format(date),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: accent.color,
            ),
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

enum _ReceiptFilter { all, approved, pending }

/// The member's receipts: totals on top, then every receipt by year.
class MemberPaymentsPage extends ConsumerStatefulWidget {
  const MemberPaymentsPage({super.key});

  @override
  ConsumerState<MemberPaymentsPage> createState() => _MemberPaymentsPageState();
}

class _MemberPaymentsPageState extends ConsumerState<MemberPaymentsPage> {
  _ReceiptFilter _filter = _ReceiptFilter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myPaymentsProvider);
    final items = async.value;
    final t = ref.watch(memberTextProvider);
    final c = context.colors;

    final shown = (items ?? const <Payment>[])
        .where((p) => switch (_filter) {
              _ReceiptFilter.all => true,
              _ReceiptFilter.approved => isApproved(p),
              _ReceiptFilter.pending =>
                p.status == PaymentStatus.pending && !p.isCancelled,
            })
        .toList();
    final years = <int, List<Payment>>{};
    for (final p in shown) {
      years.putIfAbsent(p.date.year, () => []).add(p);
    }

    return PageBody(
      maxWidth: 880,
      children: [
        SectionHeader(title: t.navPayments, subtitle: t.navPaymentsSub),
        const SizedBox(height: Space.xl),
        if (items != null && items.isNotEmpty) ...[
          _PaymentStats(items),
          const SizedBox(height: Space.xl),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final (f, label) in [
                (_ReceiptFilter.all, t.filterAll),
                (_ReceiptFilter.approved, t.filterApproved),
                (_ReceiptFilter.pending, t.pendingShort),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
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
        else if (shown.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.filter_alt_off_outlined,
              message: t.noMatchingReceipts,
            ),
          )
        else
          for (final MapEntry(key: year, value: list) in years.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm, left: 2),
              child: Text(
                '$year',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  for (final (i, p) in list.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.border),
                    MemberPaymentTile(p),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
      ],
    );
  }
}

/// Total given, receipts, this year, and anything still with the office.
class _PaymentStats extends ConsumerWidget {
  const _PaymentStats(this.items);

  final List<Payment> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(memberTextProvider);
    final approved = items.where(isApproved).toList();
    final total = approved.fold<double>(0, (s, p) => s + p.amount);
    final year = DateTime.now().year;
    final thisYear = approved
        .where((p) => p.date.year == year)
        .fold<double>(0, (s, p) => s + p.amount);
    final pending = items
        .where((p) => p.status == PaymentStatus.pending && !p.isCancelled)
        .length;

    return StatGrid(children: [
      CountUp(
        value: total,
        builder: (_, v) => StatCard(
          label: t.totalContributed,
          value: Fmt.money(v.round()),
          icon: Icons.volunteer_activism_outlined,
          accent: StatAccent.green,
        ),
      ),
      StatCard(
        label: t.approvedReceipts,
        value: '${approved.length}',
        icon: Icons.receipt_long_outlined,
        accent: StatAccent.blue,
      ),
      StatCard(
        label: '${t.thisYear} ($year)',
        value: Fmt.money(thisYear),
        icon: Icons.calendar_month_outlined,
        accent: StatAccent.purple,
      ),
      StatCard(
        label: t.pendingShort,
        value: '$pending',
        icon: Icons.schedule_rounded,
        accent: StatAccent.amber,
      ),
    ]);
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
