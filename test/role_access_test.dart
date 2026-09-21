import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/config/env.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/features/agents/agents_page.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'package:rudransh_ct/widgets/app_shell.dart';
import 'package:rudransh_ct/widgets/role_shell.dart';
import 'support/seed_data.dart';

AuthState _signedIn(UserRole role, {bool checking = false}) => AuthState(
      stage: AuthStage.signedIn,
      email: '${role.name}@test.local',
      checkingAccess: checking,
      user: AppUser(
        id: 'user-${role.name}',
        name: 'Test ${role.label}',
        email: '${role.name}@test.local',
        role: role,
      ),
    );

class _FixedAuth extends AuthController {
  _FixedAuth(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}

Future<ProviderContainer> _pumpAs(
  WidgetTester tester,
  UserRole role, {
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          seededRepository(),
        ),
        authControllerProvider.overrideWith(() => _FixedAuth(_signedIn(role))),
      ],
      child: const RudranshAdminApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(RudranshAdminApp)),
  );
}

void main() {
  group('redirectFor', () {
    test('signed out users go to login', () {
      expect(redirectFor(const AuthState(), AppRoutes.dashboard), AppRoutes.login);
      expect(redirectFor(const AuthState(), AppRoutes.agentHome), AppRoutes.login);
      expect(redirectFor(const AuthState(), AppRoutes.login), isNull);
    });

    test('each role lands on its own home after login', () {
      for (final role in UserRole.values) {
        expect(redirectFor(_signedIn(role), AppRoutes.login), role.home);
      }
      expect(UserRole.staff.home, AppRoutes.dashboard);
      expect(UserRole.agent.home, AppRoutes.agentHome);
      expect(UserRole.member.home, AppRoutes.memberHome);
    });

    test('admins cannot open agent or member screens', () {
      for (final role in [UserRole.owner, UserRole.staff]) {
        expect(redirectFor(_signedIn(role), AppRoutes.members), isNull);
        expect(redirectFor(_signedIn(role), AppRoutes.agentHome), AppRoutes.dashboard);
        expect(redirectFor(_signedIn(role), AppRoutes.memberPayments), AppRoutes.dashboard);
      }
    });

    test('agents stay in /agent', () {
      final agent = _signedIn(UserRole.agent);
      expect(redirectFor(agent, AppRoutes.agentMembers), isNull);
      expect(redirectFor(agent, AppRoutes.dashboard), AppRoutes.agentHome);
      expect(redirectFor(agent, AppRoutes.members), AppRoutes.agentHome);
      expect(redirectFor(agent, AppRoutes.memberHome), AppRoutes.agentHome);
      expect(redirectFor(agent, '/agents'), AppRoutes.agentHome);
    });

    test('members stay in /me, and /members is not /me', () {
      final member = _signedIn(UserRole.member);
      expect(redirectFor(member, AppRoutes.memberPayments), isNull);
      expect(redirectFor(member, AppRoutes.members), AppRoutes.memberHome);
      expect(redirectFor(member, AppRoutes.agentHome), AppRoutes.memberHome);
    });

    test('nothing moves while a restored session is being checked', () {
      final checking = _signedIn(UserRole.member, checking: true);
      expect(redirectFor(checking, AppRoutes.members), isNull);
    });
  });

  test('UserRole.fromName accepts database and legacy values', () {
    expect(UserRole.fromName('agent'), UserRole.agent);
    expect(UserRole.fromName('OWNER'), UserRole.owner);
    expect(UserRole.fromName('ADMIN'), isNull);
    expect(UserRole.fromName(null), isNull);
  });

  testWidgets('an agent opens the agent shell and cannot reach the admin panel',
      (tester) async {
    final container = await _pumpAs(tester, UserRole.agent);

    expect(find.byType(RoleShell), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Namaste, Test Agent'), findsOneWidget);

    container.read(routerProvider).go(AppRoutes.members);
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Namaste, Test Agent'), findsOneWidget);

    await tester.tap(find.text(S.collections).last);
    await tester.pumpAndSettle();
    expect(find.text(S.recordPayment), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a member opens the member shell', (tester) async {
    await _pumpAs(tester, UserRole.member);

    expect(find.byType(RoleShell), findsOneWidget);
    expect(find.text(S.myPayments), findsWidgets);
    expect(find.text(S.collections), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role shells lay out on a wide screen', (tester) async {
    await _pumpAs(tester, UserRole.agent, size: const Size(1600, 1000));
    expect(find.byType(RoleShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a restored session shows the access check instead of a page',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            seededRepository(),
          ),
          authControllerProvider.overrideWith(
            () => _FixedAuth(_signedIn(UserRole.owner, checking: true)),
          ),
        ],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pump();
    expect(find.text(S.checkingAccess), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  for (final (role, visible) in [(UserRole.owner, true), (UserRole.staff, false)]) {
    testWidgets(
        'invite action for agents is ${visible ? 'shown' : 'hidden'} for ${role.name}',
        (tester) async {
      final container =
          await _pumpAs(tester, role, size: const Size(1600, 1000));
      container.read(routerProvider).go(AppRoutes.agents);
      await tester.pumpAndSettle();
      expect(find.byType(AgentsPage), findsOneWidget);

      await tester.tap(find.byTooltip(S.actions).first);
      await tester.pumpAndSettle();
      expect(find.text(S.view), findsOneWidget, reason: 'actions menu is open');
      expect(find.text(S.inviteToApp), visible ? findsOneWidget : findsNothing);
    });
  }

  // Tests build without Supabase defines, so OTP must fail closed instead of
  // accepting a fake local code.
  group('sign-in without Supabase configured', () {
    Future<AuthState> request(String email) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(authControllerProvider.notifier).requestOtp(email);
      return container.read(authControllerProvider);
    }

    test('the trust email cannot receive a fake local code', () async {
      final state = await request(' ${Env.adminEmail.toUpperCase()} ');
      expect(state.stage, AuthStage.signedOut);
      expect(state.error, contains('OTP email is not configured'));
    });

    test('any other address is turned away before OTP is requested', () async {
      final state = await request('someone.else@example.com');
      expect(state.stage, isNot(AuthStage.awaitingOtp));
      expect(state.error, isNotNull);
    });
  });
}
