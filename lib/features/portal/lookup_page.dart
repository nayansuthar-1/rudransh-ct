import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/trust_repository.dart' show RepositoryException;
import '../../core/l10n/member_text.dart';
import '../../state/member_lang.dart';
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/member_lang_toggle.dart';
import '../../widgets/primitives.dart';
import '../certificate/certificate_data.dart';
import '../certificate/certificate_action.dart';
import '../receipt/receipt_action.dart';
import 'turnstile.dart';

/// Public membership check (IMPLEMENTATION_PLAN Phase 15).
///
/// Reachable without signing in, which is the point: most members have no
/// email and will never have a login. A member gives a phone number on their
/// record and the last four digits of their Aadhaar, and sees every
/// membership held under them.
class LookupPage extends ConsumerStatefulWidget {
  const LookupPage({super.key});

  @override
  ConsumerState<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends ConsumerState<LookupPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _aadhaar = TextEditingController();

  bool _busy = false;
  String? _error;
  List<MemberLookup> _found = const [];
  bool _searched = false;

  @override
  void dispose() {
    _phone.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(lookupRepositoryProvider).find(
            phone: _phone.text,
            aadhaar4: _aadhaar.text,
            // The widget below hands back a token on a real deployment; in
            // demo mode the in-memory repository ignores it.
            turnstileToken: _turnstileToken,
          );
      if (!mounted) return;
      setState(() {
        _found = result;
        _searched = true;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ref
            .read(memberTextProvider)
            .serverMessage(e is RepositoryException ? e.message : '$e');
      });
    }
  }

  /// Filled by the Turnstile widget on the web build, cleared when the token
  /// expires or the check fails. Empty everywhere else, and a configured
  /// deployment then refuses the lookup — the safe direction.
  String _turnstileToken = '';

  void _reset() {
    setState(() {
      _found = const [];
      _searched = false;
      _error = null;
      _phone.clear();
      _aadhaar.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ref.watch(memberTextProvider);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: MemberLangToggle(),
                  ),
                  Text(
                    t.trustName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.brand,
                        ),
                  ),
                  const SizedBox(height: Space.xl),
                  if (_found.isNotEmpty) ...[
                    for (final m in _found) ...[
                      _Result(m, t: t),
                      const SizedBox(height: Space.md),
                    ],
                    OutlinedButton(
                      onPressed: _reset,
                      child: Text(t.checkAnother),
                    ),
                  ] else
                    _form(context, t),
                  const SizedBox(height: Space.xl),
                  // The member login, never the office's: a public page does
                  // not point at the office sign-in.
                  TextButton(
                    onPressed: () => context.go(AppRoutes.memberLogin),
                    child: Text(t.memberSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, MemberText t) {
    final c = context.colors;
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.lookupTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.xs),
            Text(
              t.lookupSub,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: Space.lg),
            AppTextField(
              label: t.phone,
              controller: _phone,
              required: true,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').trim().length != 10
                  ? t.enterPhone
                  : null,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: t.aadhaar4,
              controller: _aadhaar,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: (v) => (v ?? '').trim().length != 4
                  ? t.enterAadhaar4
                  : null,
              onSubmitted: (_) => _submit(),
            ),
            if (_searched && _found.isEmpty) ...[
              const SizedBox(height: Space.md),
              _Notice(t.notFound, tone: c.warning, background: c.warningSoft),
            ],
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              _Notice(_error!, tone: c.danger, background: c.dangerSoft),
            ],
            if (Env.hasTurnstile) ...[
              const SizedBox(height: Space.lg),
              TurnstileWidget(
                siteKey: Env.turnstileSiteKey,
                dark: Theme.of(context).brightness == Brightness.dark,
                onToken: (token) => setState(() => _turnstileToken = token),
              ),
            ] else if (Env.hasSupabase) ...[
              const SizedBox(height: Space.md),
              _Notice(
                t.lookupOff,
                tone: c.textSecondary,
                background: c.surfaceMuted,
              ),
            ],
            const SizedBox(height: Space.lg),
            FilledButton(
              // With Turnstile on, there is no point letting someone send a
              // lookup the Edge Function will refuse: wait for the token.
              onPressed: _busy || (Env.hasTurnstile && _turnstileToken.isEmpty)
                  ? null
                  : _submit,
              child: _busy ? const ButtonSpinner() : Text(t.check),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result(this.member, {required this.t});

  final MemberLookup member;
  final MemberText t;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.name,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                t.memberStatus(member.status),
                tone: member.status == MemberStatus.active
                    ? PillTone.success
                    : PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          DetailRow(label: t.regNo, value: member.regNo),
          DetailRow(label: t.yojna, value: member.yojnaName),
          DetailRow(label: t.memberSince, value: Fmt.date(member.joinDate)),
          DetailRow(
            label: t.contribution,
            value: Fmt.money(member.contributionAmount),
          ),
          const SizedBox(height: Space.md),
          if (member.owesNothing)
            _Notice(t.nothingOwed, tone: c.success, background: c.successSoft)
          else
            _Notice(
              t.youOwe(member.duesAmount, member.duesCount),
              tone: c.warning,
              background: c.warningSoft,
            ),
          if (member.member != null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => _printCertificate(context, member, t),
              icon: const Icon(Icons.workspace_premium_outlined, size: 17),
              label: Text(t.printCertificate),
            ),
            const SizedBox(height: Space.lg),
            Text(
              t.receipts,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Space.xs),
            if (member.receipts.isEmpty)
              Text(
                t.noApprovedReceipts,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              )
            else
              for (final p in member.receipts)
                _ReceiptRow(payment: p, lookup: member, t: t),
          ],
        ],
      ),
    );
  }
}

/// One approved receipt, with a button to print it.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.payment,
    required this.lookup,
    required this.t,
  });

  final Payment payment;
  final MemberLookup lookup;
  final MemberText t;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.receiptNo,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${Fmt.date(payment.date)} · ${t.paymentKind(payment.kind)}',
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            Fmt.money(payment.amount),
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20),
            tooltip: t.printReceipt,
            onPressed: () => printPaymentReceipt(
              context,
              payment: payment,
              member: lookup.member,
              yojnaName: lookup.yojnaName,
              agentName: lookup.agentName,
            ),
          ),
        ],
      ),
    );
  }
}

/// The certificate, from what the lookup returned. Built here rather than
/// through `printMemberCertificate`, which wants the full Yojna record a
/// signed-out visitor never gets.
Future<void> _printCertificate(
  BuildContext context,
  MemberLookup l,
  MemberText t,
) async {
  final m = l.member!;
  await printCertificateData(
    context,
    CertificateData(
      regNo: m.regNo,
      issuedOn: DateTime.now(),
      name: m.name,
      fatherOrHusbandName: m.fatherOrHusbandName,
      yojnaName: l.yojnaName,
      yojnaStartedOn: l.yojnaStartedOn,
      contributionAmount: l.contributionAmount,
      payoutNote: l.payoutNote,
      gotra: m.gotra,
      jati: m.jati,
      dob: m.dob,
      village: m.village,
      district: m.district,
      state: m.state,
      address: m.address,
      phone: m.primaryPhone,
      warisName: m.warisName,
      warisRelation: m.warisRelation,
      agentName: l.agentName,
      photoUrl: m.photoUrl,
    ),
    failedMessage: t.certificateFailed,
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.tone, required this.background});

  final String message;
  final Color tone;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: tone, height: 1.4),
        ),
      );
}
