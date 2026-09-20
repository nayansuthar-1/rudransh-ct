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
import 'turnstile.dart';

/// Public membership check (IMPLEMENTATION_PLAN Phase 15).
///
/// Reachable without signing in, which is the point: most members have no
/// email and will never have a login. Registration number and phone are
/// required; the last four Aadhaar digits are checked when the office has
/// them on record.
class LookupPage extends ConsumerStatefulWidget {
  const LookupPage({super.key});

  @override
  ConsumerState<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends ConsumerState<LookupPage> {
  final _formKey = GlobalKey<FormState>();
  final _regNo = TextEditingController();
  final _phone = TextEditingController();
  final _aadhaar = TextEditingController();

  bool _busy = false;
  String? _error;
  MemberLookup? _found;
  bool _searched = false;

  @override
  void dispose() {
    _regNo.dispose();
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
            regNo: _regNo.text,
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
      _found = null;
      _searched = false;
      _error = null;
      _regNo.clear();
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
                  if (_found != null)
                    _Result(_found!, onAgain: _reset)
                  else
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
              label: S.lookupRegNo,
              controller: _regNo,
              required: true,
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your registration number.' : null,
            ),
            const SizedBox(height: Space.md),
            AppTextField(
              label: S.lookupPhone,
              controller: _phone,
              required: true,
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
              hint: S.lookupAadhaarHint,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onSubmitted: (_) => _submit(),
            ),
            if (_searched && _found == null) ...[
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
  const _Result(this.member, {required this.onAgain});

  final MemberLookup member;
  final VoidCallback onAgain;

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
          const SizedBox(height: Space.lg),
          OutlinedButton(onPressed: onAgain, child: const Text(S.lookupAgain)),
        ],
      ),
    );
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
