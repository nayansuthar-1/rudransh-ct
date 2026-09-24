import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/config/env.dart';
import '../core/l10n/member_text.dart';
import '../data/models/models.dart';
import 'member_lang.dart';

enum AuthStage { signedOut, awaitingOtp, signedIn }

/// Which login page a sign-in started on. Each page admits one kind of login
/// only, so members and agents never meet the office's sign-in, nor each
/// other's (client request, 25 Sep 2026). See `AppRoutes.loginFor`.
enum LoginPortal { office, member, agent }

@immutable
class AuthState {
  const AuthState({
    this.stage = AuthStage.signedOut,
    this.email = '',
    this.user,
    this.busy = false,
    this.checkingAccess = false,
    this.error,
    this.portal = LoginPortal.office,
  });

  final AuthStage stage;
  final String email;
  final AppUser? user;
  final bool busy;

  /// A restored session whose profile has not loaded yet. The app shows a
  /// splash instead of routing, so a reload keeps the page the user was on.
  final bool checkingAccess;
  final String? error;

  /// The login page of the current or last sign-in attempt. Another page
  /// ignores its code step and its error.
  final LoginPortal portal;

  bool get isSignedIn => stage == AuthStage.signedIn;

  AuthState copyWith({
    AuthStage? stage,
    String? email,
    AppUser? user,
    bool? busy,
    bool? checkingAccess,
    String? error,
    bool clearError = false,
    LoginPortal? portal,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      email: email ?? this.email,
      user: user ?? this.user,
      busy: busy ?? this.busy,
      checkingAccess: checkingAccess ?? this.checkingAccess,
      error: clearError ? null : (error ?? this.error),
      portal: portal ?? this.portal,
    );
  }
}

/// Email + OTP flow on Supabase Auth.
///
/// Only users invited by an owner *and* with an active profile can sign in;
/// the profile's role decides which screens open (see `app_router.dart`).
/// Without Supabase configuration the app stays signed out: OTP login must not
/// be simulated for an admin dashboard.
class AuthController extends Notifier<AuthState> {
  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  @override
  AuthState build() {
    if (!Env.hasSupabase) return const AuthState();

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

  /// Sends a sign-in code to [email], if [portal]'s page admits it. An email
  /// that belongs on another page is refused before any code is sent.
  Future<void> requestOtp(
    String email, {
    LoginPortal portal = LoginPortal.office,
  }) async {
    final address = email.trim().toLowerCase();
    final isAdmin = Env.isAdminEmail(address);
    state = state.copyWith(busy: true, clearError: true, portal: portal);

    final refusal = _refusal(isAdmin: isAdmin);
    if (refusal != null) {
      state = state.copyWith(busy: false, error: refusal);
      return;
    }

    if (!Env.hasSupabase) {
      state = state.copyWith(
        busy: false,
        error: _say(_otpUnavailable, (t) => t.signInUnavailable),
      );
      return;
    }

    try {
      // A member whose email is on their record may have no login yet: the
      // function makes one. It also activates an invited login whose invite
      // link was never opened, an agent's too.
      if (!isAdmin) await _prepareMemberLogin(address);
      // shouldCreateUser: false — an unknown email is rejected, not signed up.
      await _auth.signInWithOtp(email: address, shouldCreateUser: false);
      state = state.copyWith(
        stage: AuthStage.awaitingOtp,
        email: address,
        busy: false,
      );
    } on sb.AuthException catch (e) {
      state = state.copyWith(busy: false, error: _describeRequestError(e));
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: _say(_networkError, (t) => t.signInNetworkError),
      );
    }
  }

  /// Why this page will not send a code to this email, or null if it will.
  /// The trust's own login is never sent a code from the member or agent
  /// page, which must not become a way into the office.
  String? _refusal({required bool isAdmin}) => switch (state.portal) {
        // Staff sign in here once they are switched on (Release 2); until
        // then the office page is the trust's own login only.
        LoginPortal.office => isAdmin ? null : _officeOnly,
        LoginPortal.member =>
          isAdmin ? _say(_noAccess, (t) => t.noMemberLogin) : null,
        LoginPortal.agent => !agentsMaySignIn
            ? _agentsNotYet
            : isAdmin
                ? _noAgentLogin
                : null,
      };

  /// Why a verified login was turned away from this page.
  String _notForThisPage(AppUser? user) => switch (state.portal) {
        LoginPortal.office => user == null ? _noAccess : _officeOnly,
        LoginPortal.member => _say(_noAccess, (t) => t.noMemberLogin),
        LoginPortal.agent => agentsMaySignIn ? _noAgentLogin : _agentsNotYet,
      };

  /// [english] on the office and agent pages; on the member page, the member
  /// page's words in the member's language.
  String _say(String english, String Function(MemberText t) member) =>
      state.portal == LoginPortal.member
          ? member(ref.read(memberTextProvider))
          : english;

  /// Makes a login for a member whose email is on their record, if they have
  /// none yet. It answers the same for any address, and a failure (function
  /// not deployed, offline) only means an uninvited member gets no code.
  Future<void> _prepareMemberLogin(String email) async {
    try {
      await sb.Supabase.instance.client.functions
          .invoke('member_sign_in', body: {'email': email});
    } catch (_) {}
  }

  /// Whether agents may sign in yet. They wait for Release 2 (client
  /// decision, 24 Sep 2026); until then the Agents page offers no invite, as
  /// an invite they cannot use only confuses them. Flip it to switch agents on.
  static const agentsMaySignIn = false;

  /// Who may use the app for now: the trust's own login, members, and agents
  /// once [agentsMaySignIn]. Staff wait for Release 2.
  @visibleForTesting
  static bool mayUseApp(AppUser user) =>
      user.role == UserRole.member ||
      (agentsMaySignIn && user.role == UserRole.agent) ||
      Env.isAdminEmail(user.email);

  /// Whether [portal]'s login page lets [user] in: the office page takes the
  /// office, the member page members, the agent page agents.
  @visibleForTesting
  static bool admits(LoginPortal portal, AppUser user) =>
      mayUseApp(user) &&
      switch (portal) {
        LoginPortal.office =>
          user.role == UserRole.owner || user.role == UserRole.staff,
        LoginPortal.member => user.role == UserRole.member,
        LoginPortal.agent => user.role == UserRole.agent,
      };

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(busy: true, clearError: true);
    final token = code.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      state = state.copyWith(
        busy: false,
        error: _say('Enter the 6-digit code', (t) => t.enterCode),
      );
      return false;
    }

    if (!Env.hasSupabase) {
      state = state.copyWith(
        busy: false,
        error: _say(_otpUnavailable, (t) => t.signInUnavailable),
      );
      return false;
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
      if (appUser == null || !admits(state.portal, appUser)) {
        final portal = state.portal;
        final error = _notForThisPage(appUser);
        await _auth.signOut();
        state = AuthState(portal: portal, error: error);
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
            ? _say(_tooManyAttempts, (t) => t.signInTooMany)
            : _say(
                'The code is wrong or has expired. Request a new code.',
                (t) => t.codeWrong,
              ),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: _say(_networkError, (t) => t.signInNetworkError),
      );
      return false;
    }
  }

  /// Retry after [AuthState.checkingAccess] failed (usually offline).
  Future<void> retryAccessCheck() async {
    final user = Env.hasSupabase ? _auth.currentUser : null;
    if (user == null) return signOut();
    state = state.copyWith(clearError: true);
    await _confirmAccess(user, initial: true);
  }

  void backToEmail() =>
      state = state.copyWith(stage: AuthStage.signedOut, clearError: true);

  Future<void> signOut() async {
    if (Env.hasSupabase) {
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
      if (appUser == null || !mayUseApp(appUser)) {
        await _auth.signOut();
        if (ref.mounted) {
          state = AuthState(error: appUser == null ? _noAccess : _membersOnly);
        }
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

  String _describeRequestError(sb.AuthException e) {
    if (e.statusCode == '429') {
      return _say(_tooManyAttempts, (t) => t.signInTooMany);
    }
    final message = e.message.toLowerCase();
    if (e.code == 'otp_disabled' ||
        e.code == 'user_not_found' ||
        message.contains('signups not allowed')) {
      return switch (state.portal) {
        LoginPortal.office => _adminNotRegistered,
        LoginPortal.member => _say(_noAccess, (t) => t.noMemberLogin),
        LoginPortal.agent => _noAgentLogin,
      };
    }
    // Supabase's own wording is for the office, not for members.
    if (state.portal == LoginPortal.member) {
      return _say(_emailProviderError, (t) => t.codeNotSent);
    }
    if (e.code == 'unexpected_failure' ||
        message.contains('error sending magic link email')) {
      return _emailProviderError;
    }
    return 'Could not send the code: ${e.message}';
  }

  static const _noAccess =
      'This email does not have access. Contact the trust office.';
  static const _officeOnly = 'This sign-in is for the trust office only.';
  static const _agentsNotYet = 'Agent sign-in is not open yet. The trust '
      'office will tell you when it is.';
  static const _noAgentLogin =
      'This email has no agent login. Contact the trust office.';
  static const _membersOnly =
      'Only the trust office and members can sign in for now. Agents and '
      'staff: ask the trust office.';
  static const _adminNotRegistered =
      'This admin email is not registered in Supabase Auth.';
  static const _emailProviderError =
      'Supabase could not send the OTP email. Check the Supabase Auth email provider settings.';
  static const _tooManyAttempts =
      'Too many attempts. Please try again in a few minutes.';
  static const _networkError =
      'Network error. Check your internet connection and try again.';
  static const _otpUnavailable =
      'OTP email is not configured for this build. Connect Supabase and try again.';
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
