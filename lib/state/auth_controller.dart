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
    this.checkingAccess = false,
    this.error,
  });

  final AuthStage stage;
  final String email;
  final AppUser? user;
  final bool busy;

  /// A restored session whose profile has not loaded yet. The app shows a
  /// splash instead of routing, so a reload keeps the page the user was on.
  final bool checkingAccess;
  final String? error;

  bool get isSignedIn => stage == AuthStage.signedIn;

  AuthState copyWith({
    AuthStage? stage,
    String? email,
    AppUser? user,
    bool? busy,
    bool? checkingAccess,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      email: email ?? this.email,
      user: user ?? this.user,
      busy: busy ?? this.busy,
      checkingAccess: checkingAccess ?? this.checkingAccess,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Email + OTP flow on Supabase Auth.
///
/// Only users invited by an owner *and* with an active profile can sign in;
/// the profile's role decides which screens open (see `app_router.dart`).
/// Without Supabase configuration (demo mode) the app opens straight in, as
/// an owner unless `DEMO_ROLE` says otherwise.
class AuthController extends Notifier<AuthState> {
  static bool get bypassLogin => Env.demoMode;

  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  @override
  AuthState build() {
    if (bypassLogin) {
      return AuthState(
        stage: AuthStage.signedIn,
        email: AppUser.guest.email,
        user: _demoUser(AppUser.guest.email),
      );
    }

    final sub = _auth.onAuthStateChange.listen(_onAuthChange);
    ref.onDispose(sub.cancel);

    // Supabase.initialize has already restored a saved session, if any.
    final session = _auth.currentSession;
    if (session == null) return const AuthState();

    Future.microtask(() => _confirmAccess(session.user, initial: true));
    return AuthState(
      stage: AuthStage.signedIn,
      email: session.user.email ?? '',
      user: _userFrom(session.user),
      checkingAccess: true,
    );
  }

  Future<void> requestOtp(String email) async {
    final address = email.trim().toLowerCase();
    state = state.copyWith(busy: true, clearError: true);

    if (bypassLogin) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      // A demo build has no database to check against, so the trust's own
      // address is the only one it accepts. Without this any address at all
      // would open the panel.
      if (!Env.isAdminEmail(address)) {
        state = state.copyWith(busy: false, error: _noAccess);
        return;
      }
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
        user: _demoUser(state.email),
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

      final appUser = await _loadProfile(user);
      if (appUser == null) {
        await _auth.signOut();
        state = const AuthState(error: _noAccess);
        return false;
      }

      state = AuthState(
        stage: AuthStage.signedIn,
        email: user.email ?? state.email,
        user: appUser,
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

  /// Retry after [AuthState.checkingAccess] failed (usually offline).
  Future<void> retryAccessCheck() async {
    final user = bypassLogin ? null : _auth.currentUser;
    if (user == null) return signOut();
    state = state.copyWith(clearError: true);
    await _confirmAccess(user, initial: true);
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
    switch (event.event) {
      // Refresh token expired, or signed out in another tab.
      case sb.AuthChangeEvent.signedOut when state.isSignedIn:
        state = const AuthState();
      // Hourly: an owner may have deactivated this user or their agent record
      // since they signed in. The database already refuses their data.
      case sb.AuthChangeEvent.tokenRefreshed when state.isSignedIn:
        final user = event.session?.user;
        if (user != null) _confirmAccess(user, initial: false);
      default:
        break;
    }
  }

  Future<void> _confirmAccess(sb.User user, {required bool initial}) async {
    try {
      final appUser = await _loadProfile(user);
      if (!ref.mounted || !state.isSignedIn) return;
      if (appUser == null) {
        await _auth.signOut();
        if (ref.mounted) state = const AuthState(error: _noAccess);
      } else {
        state = state.copyWith(
          user: appUser,
          checkingAccess: false,
          clearError: true,
        );
      }
    } catch (_) {
      // Offline. On a reload the splash offers a retry; later re-checks keep
      // the session, and the database still refuses data it should not see.
      if (initial && ref.mounted) state = state.copyWith(error: _networkError);
    }
  }

  /// The active profile for [user], or null when they have no access.
  Future<AppUser?> _loadProfile(sb.User user) async {
    final client = sb.Supabase.instance.client;
    final fallback = _userFrom(user);

    List<dynamic> rows;
    try {
      rows = await client.rpc('my_profile') as List<dynamic>;
    } on sb.PostgrestException catch (e) {
      // Database without the roles migration yet: admins only.
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
      rows = await client
          .from('admins')
          .select('name, email, role')
          .eq('user_id', user.id)
          .limit(1);
    }
    if (rows.isEmpty) return null;

    final row = rows.first as Map<String, dynamic>;
    final role = UserRole.fromName(row['role'] as String?) ??
        // Legacy `admins.role` is 'ADMIN'.
        UserRole.owner;
    final name = (row['name'] as String?)?.trim() ?? '';
    return AppUser(
      id: user.id,
      name: name.isEmpty ? fallback.name : name,
      email: user.email ?? fallback.email,
      role: role,
      agentId: row['agent_id'] as String?,
      memberId: row['member_id'] as String?,
    );
  }

  /// Placeholder while [AuthState.checkingAccess]: the role with least access.
  static AppUser _userFrom(sb.User user) {
    final email = user.email ?? '';
    return AppUser(
      id: user.id,
      name: email.split('@').first.toUpperCase(),
      email: email,
      role: UserRole.member,
    );
  }

  static AppUser _demoUser(String email) {
    final role = UserRole.fromName(Env.demoRole) ?? UserRole.owner;
    return AppUser(
      id: 'local-${role.name}',
      name: role == UserRole.owner
          ? AppUser.guest.name
          : '${email.split('@').first.toUpperCase()} (${role.label})',
      email: email,
      role: role,
      agentId: role == UserRole.agent ? 'demo-agent' : null,
      memberId: role == UserRole.member ? 'demo-member' : null,
    );
  }

  static String _describeRequestError(sb.AuthException e) {
    if (e.statusCode == '429') return _tooManyAttempts;
    final message = e.message.toLowerCase();
    if (e.code == 'otp_disabled' ||
        e.code == 'user_not_found' ||
        message.contains('signups not allowed')) {
      return _noAccess;
    }
    return 'Could not send the code: ${e.message}';
  }

  static const _noAccess =
      'This email does not have access. Contact the trust office.';
  static const _tooManyAttempts =
      'Too many attempts. Please try again in a few minutes.';
  static const _networkError =
      'Network error. Check your internet connection and try again.';
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AppUser>((ref) {
  return ref.watch(authControllerProvider).user ?? AppUser.guest;
});

/// Signed-in user id. Data providers watch it so they reload after sign-in
/// and drop cached records after sign-out.
final sessionUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider.select((s) => s.user?.id));
});
