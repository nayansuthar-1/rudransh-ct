import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/config/env.dart';
import 'package:rudransh_ct/core/l10n/member_text.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/access_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart'
    show RepositoryException;
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
    test('signed out users go to the login page for that part of the app', () {
      const out = AuthState();
      expect(redirectFor(out, AppRoutes.dashboard), AppRoutes.login);
      expect(redirectFor(out, AppRoutes.members), AppRoutes.login);
      expect(redirectFor(out, AppRoutes.agentHome), AppRoutes.agentLogin);
      expect(redirectFor(out, AppRoutes.agentDues), AppRoutes.agentLogin);
      expect(redirectFor(out, AppRoutes.memberHome), AppRoutes.memberLogin);
      expect(redirectFor(out, AppRoutes.memberPayments), AppRoutes.memberLogin);
      for (final page in AppRoutes.loginPages) {
        expect(redirectFor(out, page), isNull);
      }
    });

    test('the bare site address opens the member login, not the office one',
        () {
      expect(
        redirectFor(const AuthState(), AppRoutes.root),
        AppRoutes.memberLogin,
      );
    });

    test('each role lands on its own home after login', () {
      for (final role in UserRole.values) {
        for (final page in AppRoutes.loginPages) {
          expect(redirectFor(_signedIn(role), page), role.home);
        }
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
    // The member side opens in Hindi.
    expect(
      find.text(const MemberText(MemberLang.hi).navPayments),
      findsWidgets,
    );
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

  // The owner is offered the invite only once agents may sign in.
  for (final (role, visible) in [
    (UserRole.owner, AuthController.agentsMaySignIn),
    (UserRole.staff, false),
  ]) {
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

  group('inviting a member to the app', () {
    /// Opens the actions menu of each visible member row in turn and returns
    /// the index of the first that offers the invite, or -1. Leaves that
    /// menu open.
    Future<int> openRowWithInvite(WidgetTester tester) async {
      final buttons = find.byTooltip(S.actions);
      final count = buttons.evaluate().length;
      for (var i = 0; i < count; i++) {
        await tester.tap(buttons.at(i));
        await tester.pumpAndSettle();
        if (find.text(S.inviteToApp).evaluate().isNotEmpty) return i;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      return -1;
    }

    testWidgets('staff never see the invite', (tester) async {
      final container =
          await _pumpAs(tester, UserRole.staff, size: const Size(1600, 1000));
      container.read(routerProvider).go(AppRoutes.members);
      await tester.pumpAndSettle();
      expect(find.byTooltip(S.actions), findsWidgets);
      expect(await openRowWithInvite(tester), -1);
    });

    testWidgets('the owner invites a member by email', (tester) async {
      final container =
          await _pumpAs(tester, UserRole.owner, size: const Size(1600, 1000));
      container.read(routerProvider).go(AppRoutes.members);
      await tester.pumpAndSettle();

      final row = await openRowWithInvite(tester);
      expect(row, isNot(-1), reason: 'an approved member offers the invite');
      await tester.tap(find.text(S.inviteToApp));
      await tester.pumpAndSettle();

      // An email is required before anything is sent.
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, 'Member@Example.com');
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();
      expect(find.text(S.inviteSent), findsOneWidget);
      expect(await container.read(memberAccessProvider.future), hasLength(1));

      // Once invited, that member no longer offers it.
      await tester.tap(find.byTooltip(S.actions).at(row));
      await tester.pumpAndSettle();
      expect(find.text(S.inviteToApp), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('who may use the app until Release 2', () {
    AppUser user(UserRole role, String email) =>
        AppUser(id: 'u', name: 'U', email: email, role: role);

    test('members may sign in, from any address', () {
      expect(
        AuthController.mayUseApp(user(UserRole.member, 'ram@example.com')),
        isTrue,
      );
    });

    test("the trust's own login may sign in", () {
      expect(
        AuthController.mayUseApp(user(UserRole.owner, Env.adminEmail)),
        isTrue,
      );
    });

    test('agents and other staff wait for Release 2', () {
      expect(
        AuthController.mayUseApp(user(UserRole.agent, 'agent@example.com')),
        AuthController.agentsMaySignIn,
      );
      expect(
        AuthController.mayUseApp(user(UserRole.staff, 'staff@example.com')),
        isFalse,
      );
      expect(
        AuthController.mayUseApp(user(UserRole.owner, 'other@example.com')),
        isFalse,
      );
    });
  });

  group('login pages', () {
    Future<void> open(WidgetTester tester, String page) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider
                .overrideWith(() => _FixedAuth(const AuthState())),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      ProviderScope.containerOf(tester.element(find.byType(RudranshAdminApp)))
          .read(routerProvider)
          .go(page);
      await tester.pumpAndSettle();
    }

    testWidgets('the member login is in Hindi and says nothing of the office',
        (tester) async {
      await open(tester, AppRoutes.memberLogin);
      expect(find.text(const MemberText(MemberLang.hi).signInTitle),
          findsOneWidget);
      expect(find.text(const MemberText(MemberLang.hi).noEmailLookup),
          findsOneWidget);
      expect(find.textContaining('office'), findsNothing);
      expect(find.text(S.officeSignIn), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the office login does not point members anywhere',
        (tester) async {
      await open(tester, AppRoutes.login);
      expect(
        find.text(AuthController.agentsMaySignIn ? S.signIn : S.officeSignIn),
        findsOneWidget,
      );
      expect(find.text(const MemberText(MemberLang.hi).noEmailLookup),
          findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('the agent login is its own page', (tester) async {
      await open(tester, AppRoutes.agentLogin);
      expect(find.text(S.agentSignIn), findsOneWidget);
      expect(find.text(S.officeSignIn), findsNothing);
    });
  });

  group('each login page admits its own role only', () {
    AppUser user(UserRole role, String email) =>
        AppUser(id: 'u', name: 'U', email: email, role: role);
    final office = user(UserRole.owner, Env.adminEmail);
    final member = user(UserRole.member, 'ram@example.com');
    final agent = user(UserRole.agent, 'agent@example.com');

    test('the office page takes the office, and agents once they may', () {
      expect(AuthController.admits(LoginPortal.office, office), isTrue);
      expect(AuthController.admits(LoginPortal.office, member), isFalse);
      expect(
        AuthController.admits(LoginPortal.office, agent),
        AuthController.agentsMaySignIn,
      );
    });

    test('the member page takes members only', () {
      expect(AuthController.admits(LoginPortal.member, member), isTrue);
      expect(AuthController.admits(LoginPortal.member, office), isFalse);
      expect(AuthController.admits(LoginPortal.member, agent), isFalse);
    });

    test('the agent page takes agents only, once they may sign in', () {
      expect(
        AuthController.admits(LoginPortal.agent, agent),
        AuthController.agentsMaySignIn,
      );
      expect(AuthController.admits(LoginPortal.agent, office), isFalse);
      expect(AuthController.admits(LoginPortal.agent, member), isFalse);
    });
  });

  group('member invites in memory', () {
    final member = seededRepository()
        .membersView
        .firstWhere((m) => m.status == MemberStatus.active);

    test('a pending member cannot be invited', () {
      expect(
        () => InMemoryAccessRepository().inviteMember(
          member.copyWith(status: MemberStatus.pending),
          'a@example.com',
        ),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('a member is invited once', () async {
      final repo = InMemoryAccessRepository();
      await repo.inviteMember(member, 'a@example.com');
      expect(await repo.fetchMemberAccess(), {member.id: true});
      expect(
        () => repo.inviteMember(member, 'a@example.com'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

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

  group('login pages refuse the wrong email before sending a code', () {
    Future<AuthState> request(String email, LoginPortal portal) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .requestOtp(email, portal: portal);
      return container.read(authControllerProvider);
    }

    // With agents on, the office page cannot tell a member from an agent
    // before the code; [AuthController.admits] turns the member away after.
    test('the office page turns a member away', () async {
      final state = await request('ram@example.com', LoginPortal.office);
      expect(state.stage, AuthStage.signedOut);
      if (!AuthController.agentsMaySignIn) {
        expect(state.error, contains('trust office only'));
      }
    });

    test("the member page will not send the office's login a code", () async {
      final state = await request(Env.adminEmail, LoginPortal.member);
      expect(state.stage, AuthStage.signedOut);
      expect(state.portal, LoginPortal.member);
      expect(state.error, isNot(contains('OTP email is not configured')));
    });

    test('the agent page is closed until agents may sign in', () async {
      final state = await request('agent@example.com', LoginPortal.agent);
      expect(state.stage, AuthStage.signedOut);
      if (!AuthController.agentsMaySignIn) {
        expect(state.error, contains('not open yet'));
      }
    });
  });
}
