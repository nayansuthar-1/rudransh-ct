import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/config/env.dart';
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

/// Email + OTP flow on Supabase Auth.
///
/// Only users invited from the Supabase dashboard *and* listed in the
/// `admins` table can sign in. Without Supabase configuration (demo mode)
/// the panel opens straight to the dashboard on seed data.
class AuthController extends Notifier<AuthState> {
  static bool get bypassLogin => Env.demoMode;

  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  @override
  AuthState build() {
    if (bypassLogin) {
      return const AuthState(
        stage: AuthStage.signedIn,
        email: 'rudranshct@gmail.com',
        user: AdminUser.guest,
      );
    }

    final sub = _auth.onAuthStateChange.listen(_onAuthChange);
    ref.onDispose(sub.cancel);

    // Supabase.initialize has already restored a saved session, if any.
    final session = _auth.currentSession;
    if (session == null) return const AuthState();

    // Re-check admin access in the background; RLS protects the data meanwhile.
    Future.microtask(() => _confirmAdmin(session.user));
    return AuthState(
      stage: AuthStage.signedIn,
      email: session.user.email ?? '',
      user: _userFrom(session.user),
    );
  }

  Future<void> requestOtp(String email) async {
    final address = email.trim().toLowerCase();
    state = state.copyWith(busy: true, clearError: true);

    if (bypassLogin) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      state = state.copyWith(
        stage: AuthStage.awaitingOtp,
        email: address,
        busy: false,
      );
      return;
    }

    try {
      // shouldCreateUser: false — an uninvited email is rejected, not signed up.
      await _auth.signInWithOtp(email: address, shouldCreateUser: false);
      state = state.copyWith(
        stage: AuthStage.awaitingOtp,
        email: address,
        busy: false,
      );
    } on sb.AuthException catch (e) {
      state = state.copyWith(busy: false, error: _describeRequestError(e));
    } catch (_) {
      state = state.copyWith(busy: false, error: _networkError);
    }
  }

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(busy: true, clearError: true);
    final token = code.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      state = state.copyWith(busy: false, error: 'Enter the 6-digit code');
      return false;
    }

    if (bypassLogin) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
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

    try {
      final response = await _auth.verifyOTP(
        type: sb.OtpType.email,
        email: state.email,
        token: token,
      );
      final user = response.user;
      if (user == null) throw const sb.AuthException('No user in response');

      final admin = await _loadAdmin(user);
      if (admin == null) {
        await _auth.signOut();
        state = const AuthState(error: _notAdmin);
        return false;
      }

      state = AuthState(
        stage: AuthStage.signedIn,
        email: user.email ?? state.email,
        user: admin,
      );
      return true;
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.statusCode == '429'
            ? _tooManyAttempts
            : 'The code is wrong or has expired. Request a new code.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, error: _networkError);
      return false;
    }
  }

  void backToEmail() =>
      state = state.copyWith(stage: AuthStage.signedOut, clearError: true);

  Future<void> signOut() async {
    if (!bypassLogin) {
      try {
        await _auth.signOut();
      } catch (_) {
        // The local session is cleared even if the network call fails.
      }
    }
    state = const AuthState();
  }

  // ---- Internals ----------------------------------------------------------

  void _onAuthChange(sb.AuthState event) {
    // Refresh token expired, or signed out in another tab.
    if (event.event == sb.AuthChangeEvent.signedOut && state.isSignedIn) {
      state = const AuthState();
    }
  }

  Future<void> _confirmAdmin(sb.User user) async {
    try {
      final admin = await _loadAdmin(user);
      if (!ref.mounted || !state.isSignedIn) return;
      if (admin == null) {
        await _auth.signOut();
        if (ref.mounted) state = const AuthState(error: _notAdmin);
      } else {
        state = state.copyWith(user: admin);
      }
    } catch (_) {
      // Offline: keep the restored session; data calls will surface errors.
    }
  }

  /// The `admins` row for [user], or null when they are not an admin.
  Future<AdminUser?> _loadAdmin(sb.User user) async {
    final row = await sb.Supabase.instance.client
        .from('admins')
        .select('name, email, role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    final fallback = _userFrom(user);
    final name = (row['name'] as String?)?.trim() ?? '';
    return AdminUser(
      id: user.id,
      name: name.isEmpty ? fallback.name : name,
      email: user.email ?? fallback.email,
      role: row['role'] as String? ?? 'ADMIN',
    );
  }

  static AdminUser _userFrom(sb.User user) {
    final email = user.email ?? '';
    return AdminUser(
      id: user.id,
      name: email.split('@').first.toUpperCase(),
      email: email,
    );
  }

  static String _describeRequestError(sb.AuthException e) {
    if (e.statusCode == '429') return _tooManyAttempts;
    final message = e.message.toLowerCase();
    if (e.code == 'otp_disabled' ||
        e.code == 'user_not_found' ||
        message.contains('signups not allowed')) {
      return _notAdmin;
    }
    return 'Could not send the code: ${e.message}';
  }

  static const _notAdmin =
      'This email is not registered as an admin. Contact the trust office.';
  static const _tooManyAttempts =
      'Too many attempts. Please try again in a few minutes.';
  static const _networkError =
      'Network error. Check your internet connection and try again.';
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AdminUser>((ref) {
  return ref.watch(authControllerProvider).user ?? AdminUser.guest;
});

/// Signed-in user id. Data providers watch it so they reload after sign-in
/// and drop cached records after sign-out.
final sessionUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider.select((s) => s.user?.id));
});
