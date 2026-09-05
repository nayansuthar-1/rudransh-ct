import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';

enum AuthStage { signedOut, awaitingOtp, signedIn }

@immutable
class AuthState {
  const AuthState({
    this.stage = AuthStage.signedOut,
    this.email = '',
    this.user,
    this.busy = false,
    this.error,
  });

  final AuthStage stage;
  final String email;
  final AdminUser? user;
  final bool busy;
  final String? error;

  bool get isSignedIn => stage == AuthStage.signedIn;

  AuthState copyWith({
    AuthStage? stage,
    String? email,
    AdminUser? user,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      email: email ?? this.email,
      user: user ?? this.user,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Email + OTP flow.
///
/// The transport is stubbed for now — [requestOtp] pretends to send a code and
/// [verifyOtp] accepts any 6-digit value. Wire the two methods to Firebase
/// Auth / Supabase OTP / your own API and nothing else has to change.
class AuthController extends Notifier<AuthState> {
  /// While true the panel opens straight to the dashboard. Flip to `false`
  /// once a real OTP backend is connected.
  static const bypassLogin = true;

  @override
  AuthState build() => bypassLogin
      ? const AuthState(
          stage: AuthStage.signedIn,
          email: 'rudranshctm@gmail.com',
          user: AdminUser.guest,
        )
      : const AuthState();

  Future<void> requestOtp(String email) async {
    state = state.copyWith(busy: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // TODO(auth): call the real OTP endpoint here.
    state = state.copyWith(
      stage: AuthStage.awaitingOtp,
      email: email.trim(),
      busy: false,
    );
  }

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(busy: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // TODO(auth): verify against the backend instead of a shape check.
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      state = state.copyWith(busy: false, error: 'Enter the 6-digit code');
      return false;
    }

    state = state.copyWith(
      stage: AuthStage.signedIn,
      busy: false,
      user: AdminUser(
        id: 'local-admin',
        name: state.email.split('@').first.toUpperCase(),
        email: state.email,
      ),
    );
    return true;
  }

  void backToEmail() =>
      state = state.copyWith(stage: AuthStage.signedOut, clearError: true);

  void signOut() => state = const AuthState();
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AdminUser>((ref) {
  return ref.watch(authControllerProvider).user ?? AdminUser.guest;
});
