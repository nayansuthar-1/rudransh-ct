import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_controller.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

/// Email + OTP sign-in. The transport is stubbed in [AuthController] — see the
/// TODOs there when wiring a real backend.
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
    final wide = context.screenWidth >= Breakpoints.tablet;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: AppCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.spa_rounded,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.appName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      S.appSubtitle,
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              auth.stage == AuthStage.awaitingOtp ? S.otpLabel : S.signIn,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              auth.stage == AuthStage.awaitingOtp
                  ? '${S.otpSentTo} ${auth.email}'
                  : S.signInSubtitle,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 22),

            if (auth.stage == AuthStage.awaitingOtp)
              Form(
                key: _otpKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: S.otpLabel,
                      controller: _otp,
                      autofocus: true,
                      hint: '••••••',
                      keyboardType: TextInputType.number,
                      inputFormatters: Fmts.otp(),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verify(controller),
                      validator: (v) =>
                          RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Enter the 6-digit code',
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        auth.error!,
                        style: TextStyle(fontSize: 12.5, color: c.danger),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: auth.busy ? null : () => _verify(controller),
                      child: auth.busy
                          ? const _ButtonSpinner()
                          : const Text(S.verify),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed:
                              auth.busy ? null : controller.backToEmail,
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
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendOtp(controller),
                      validator: V.email,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: auth.busy ? null : () => _sendOtp(controller),
                      child: auth.busy
                          ? const _ButtonSpinner()
                          : const Text(S.sendOtp),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Text(
              'Demo build — any 6-digit code signs you in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 32 : 16,
              vertical: 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.trustName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: wide ? 24 : 19,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                card,
              ],
            ),
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

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
