import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/trust_repository.dart' show RepositoryException;
import '../../state/providers.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../certificate/certificate_data.dart';
import '../certificate/certificate_printer.dart';
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
        _error = e is RepositoryException ? e.message : '$e';
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
                  Text(
                    S.trustName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.brand,
                        ),
                  ),
                  const SizedBox(height: Space.xl),
                  if (_found.isNotEmpty) ...[
                    for (final m in _found) ...[
                      _Result(m),
                      const SizedBox(height: Space.md),
                    ],
                    OutlinedButton(
                      onPressed: _reset,
                      child: const Text(S.lookupAgain),
                    ),
                  ] else
                    _form(context),
                  const SizedBox(height: Space.xl),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Staff and agents: sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.lookupTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.xs),
            Text(
              S.lookupSub,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: Space.lg),
            AppTextField(
              label: S.lookupPhone,
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
                  ? 'Enter the 10-digit phone number.'
                  : null,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.lookupAadhaar,
              controller: _aadhaar,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: (v) => (v ?? '').trim().length != 4
                  ? 'Enter the last 4 digits of your Aadhaar.'
                  : null,
              onSubmitted: (_) => _submit(),
            ),
            if (_searched && _found.isEmpty) ...[
              const SizedBox(height: Space.md),
              _Notice(S.lookupNotFound, tone: c.warning, background: c.warningSoft),
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
                'This check is not switched on yet. Please contact the office.',
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
              child: _busy ? const ButtonSpinner() : const Text(S.lookupSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result(this.member);

  final MemberLookup member;

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
                member.status.label,
                tone: member.status == MemberStatus.active
                    ? PillTone.success
                    : PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          DetailRow(label: S.lookupRegNo, value: member.regNo),
          DetailRow(label: S.yojna, value: member.yojnaName),
          DetailRow(label: 'Member since', value: Fmt.date(member.joinDate)),
          DetailRow(
            label: 'Contribution',
            value: Fmt.money(member.contributionAmount),
          ),
          const SizedBox(height: Space.md),
          if (member.owesNothing)
            _Notice(S.nothingOwed, tone: c.success, background: c.successSoft)
          else
            _Notice(
              'You owe ${Fmt.money(member.duesAmount)} '
              'for ${member.duesCount} closing(s). '
              'Pay your agent or the office.',
              tone: c.warning,
              background: c.warningSoft,
            ),
          if (member.member != null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => _printCertificate(context, member),
              icon: const Icon(Icons.workspace_premium_outlined, size: 17),
              label: const Text(S.printCertificate),
            ),
            const SizedBox(height: Space.lg),
            Text(
              'Receipts',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Space.xs),
            if (member.receipts.isEmpty)
              Text(
                'No approved receipts yet.',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              )
            else
              for (final p in member.receipts)
                _ReceiptRow(payment: p, lookup: member),
          ],
        ],
      ),
    );
  }
}

/// One approved receipt, with a button to print it.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.payment, required this.lookup});

  final Payment payment;
  final MemberLookup lookup;

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
                  '${Fmt.date(payment.date)} · ${payment.kind.label}',
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
            tooltip: 'Print receipt',
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
Future<void> _printCertificate(BuildContext context, MemberLookup l) async {
  final m = l.member!;
  final opened = await openCertificateForPrint(
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
  );
  if (!opened && context.mounted) {
    showToast(context, S.certificateFailed, error: true);
  }
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
