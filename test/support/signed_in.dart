import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:rudransh_ct/core/config/env.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/state/auth_controller.dart';

/// Holds a fixed sign-in state, so widget tests open straight on the screens
/// they check. Since 21 Sep 2026 the app has no demo auto-login: without this
/// a test lands on the sign-in page.
class FixedAuth extends AuthController {
  FixedAuth(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

/// A provider override signing the app in as [role]. The owner uses the
/// trust's own login, as in production.
Override signedInAs(
  UserRole role, {
  String? agentId,
  String? memberId,
}) {
  final email =
      role == UserRole.owner ? Env.adminEmail : '${role.name}@test.local';
  return authControllerProvider.overrideWith(
    () => FixedAuth(
      AuthState(
        stage: AuthStage.signedIn,
        email: email,
        user: AppUser(
          id: 'user-${role.name}',
          name: 'Test ${role.label}',
          email: email,
          role: role,
          agentId: agentId,
          memberId: memberId,
        ),
      ),
    ),
  );
}
