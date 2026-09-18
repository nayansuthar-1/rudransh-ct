import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_controller.dart';
import '../../widgets/inputs.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_sidebar.dart';

/// Email + OTP sign-in. See [AuthController] for the Supabase flow.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

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

    final awaitingOtp = auth.stage == AuthStage.awaitingOtp;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: BrandMark(size: 36),
          ),
          const SizedBox(height: 28),
          Text(
            awaitingOtp ? 'Check your email' : S.signIn,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            awaitingOtp
                ? '${S.otpSentTo} ${auth.email}'
                : '${S.trustName} · ${S.signInSubtitle}',
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
                    label: S.otpLabel,
                    controller: _otp,
                    autofocus: true,
                    hint: '6-digit code',
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.otp(),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(controller),
                    validator: (v) =>
                        RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Enter the 6-digit code',
                  ),
                  if (auth.error != null) _ErrorText(auth.error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.busy ? null : () => _verify(controller),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: auth.busy
                        ? const ButtonSpinner()
                        : const Text(S.verify),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: auth.busy ? null : controller.backToEmail,
                        child: const Text(S.changeEmail),
                      ),
                      TextButton(
                        onPressed: auth.busy
                            ? null
                            : () => controller.requestOtp(auth.email),
                        child: const Text(S.resendOtp),
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
                    label: S.emailLabel,
                    controller: _email,
                    autofocus: true,
                    hint: S.emailHint,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendOtp(controller),
                    validator: V.email,
                  ),
                  if (auth.error != null) _ErrorText(auth.error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.busy ? null : () => _sendOtp(controller),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: auth.busy
                        ? const ButtonSpinner()
                        : const Text(S.sendOtp),
                  ),
                ],
              ),
            ),

          // Most members have no login, so the public check is the way in
          // for them (IMPLEMENTATION_PLAN Phase 15).
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go(AppRoutes.lookup),
            child: const Text('Members: check your membership'),
          ),

          if (Env.demoMode) ...[
            const SizedBox(height: 24),
            Text(
              'Demo build — any 6-digit code signs you in.',
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
    controller.requestOtp(_email.text.trim());
  }

  void _verify(AuthController controller) {
    if (!(_otpKey.currentState?.validate() ?? false)) return;
    controller.verifyOtp(_otp.text.trim());
  }
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
