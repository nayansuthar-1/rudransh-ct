import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/l10n/member_text.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_controller.dart';
import '../../state/member_lang.dart';
import '../../widgets/inputs.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/member_lang_toggle.dart';

/// Email + OTP sign-in, one page per [LoginPortal]: the office at `/login`,
/// members at `/m` (Hindi first), agents at `/a`. Each admits its own kind of
/// login only; see [AuthController] for the Supabase flow.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.portal = LoginPortal.office});

  final LoginPortal portal;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final isMember = widget.portal == LoginPortal.member;
    final copy = isMember
        ? _Copy.member(ref.watch(memberTextProvider))
        : _Copy.forPortal(widget.portal);

    // A sign-in begun on another login page is not this page's business.
    final ours = auth.portal == widget.portal;
    final awaitingOtp = ours && auth.stage == AuthStage.awaitingOtp;
    final error = ours ? auth.error : null;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandMark(size: 36),
              const Spacer(),
              if (isMember) const MemberLangToggle(),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            awaitingOtp ? copy.checkEmail : copy.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            awaitingOtp ? '${copy.codeSentTo} ${auth.email}' : copy.subtitle,
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 28),

          if (awaitingOtp)
            Form(
              key: _otpKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: copy.codeLabel,
                    controller: _otp,
                    autofocus: true,
                    hint: S.otpHint,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.otp(),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(controller),
                    validator: (v) =>
                        RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : copy.enterCode,
                  ),
                  if (error != null) _ErrorText(error),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.busy ? null : () => _verify(controller),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: auth.busy
                        ? const ButtonSpinner()
                        : Text(copy.verify),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: auth.busy ? null : controller.backToEmail,
                        child: Text(copy.changeEmail),
                      ),
                      TextButton(
                        onPressed: auth.busy
                            ? null
                            : () => controller.requestOtp(
                                  auth.email,
                                  portal: widget.portal,
                                ),
                        child: Text(copy.resend),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Form(
              key: _emailKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: copy.emailLabel,
                    controller: _email,
                    autofocus: true,
                    hint: copy.emailHint,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendOtp(controller),
                    validator: (v) => V.email(v) == null ? null : copy.badEmail,
                  ),
                  if (error != null) _ErrorText(error),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.busy ? null : () => _sendOtp(controller),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: auth.busy
                        ? const ButtonSpinner()
                        : Text(copy.sendCode),
                  ),
                ],
              ),
            ),

          // Most members have no email, so the public check is the way in
          // for them (IMPLEMENTATION_PLAN Phase 15).
          if (isMember) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.lookup),
              child: Text(ref.watch(memberTextProvider).noEmailLookup),
            ),
          ],

          if (Env.demoMode) ...[
            const SizedBox(height: 24),
            Text(
              'OTP email is not configured in this build.',
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: form,
          ),
        ),
      ),
    );
  }

  void _sendOtp(AuthController controller) {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    controller.requestOtp(_email.text.trim(), portal: widget.portal);
  }

  void _verify(AuthController controller) {
    if (!(_otpKey.currentState?.validate() ?? false)) return;
    controller.verifyOtp(_otp.text.trim());
  }
}

/// The words on one login page.
class _Copy {
  const _Copy({
    required this.title,
    required this.subtitle,
    required this.emailLabel,
    required this.emailHint,
    required this.badEmail,
    required this.sendCode,
    required this.checkEmail,
    required this.codeSentTo,
    required this.codeLabel,
    required this.enterCode,
    required this.verify,
    required this.changeEmail,
    required this.resend,
  });

  /// The office and agent pages, in English like the rest of their screens.
  factory _Copy.forPortal(LoginPortal portal) {
    final agent = portal == LoginPortal.agent;
    return _Copy(
      title: agent ? S.agentSignIn : S.officeSignIn,
      subtitle:
          '${S.trustName} · ${agent ? S.agentSignInSub : S.officeSignInSub}',
      emailLabel: S.emailLabel,
      emailHint: agent ? 'name@example.com' : S.emailHint,
      badEmail: S.invalidEmail,
      sendCode: S.sendOtp,
      checkEmail: S.checkEmail,
      codeSentTo: S.otpSentTo,
      codeLabel: S.otpLabel,
      enterCode: S.enterOtp,
      verify: S.verify,
      changeEmail: S.changeEmail,
      resend: S.resendOtp,
    );
  }

  /// The member page, in the member's language (Hindi by default).
  factory _Copy.member(MemberText t) => _Copy(
        title: t.signInTitle,
        subtitle: '${t.trustName}\n${t.signInSub}',
        emailLabel: t.email,
        emailHint: 'name@example.com',
        badEmail: t.enterEmail,
        sendCode: t.sendCode,
        checkEmail: t.checkEmail,
        codeSentTo: t.codeSentTo,
        codeLabel: t.code,
        enterCode: t.enterCode,
        verify: t.signInButton,
        changeEmail: t.changeEmail,
        resend: t.resendCode,
      );

  final String title;
  final String subtitle;
  final String emailLabel;
  final String emailHint;
  final String badEmail;
  final String sendCode;
  final String checkEmail;
  final String codeSentTo;
  final String codeLabel;
  final String enterCode;
  final String verify;
  final String changeEmail;
  final String resend;
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: context.colors.danger),
      ),
    );
  }
}
