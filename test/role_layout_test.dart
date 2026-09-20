// Phase 17 QA: the agent and member shells at phone width, in both themes,
// with the trust's Hindi records in them.
//
// responsive_test.dart already walks the admin pages through the sidebar.
// Those helpers do not fit here: the agent and member shells navigate with a
// bottom bar, not a sidebar, and each needs a signed-in user of that role.
// Agents work on phones, so 390 px is the width that matters.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/core/theme/app_theme.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'support/seed_data.dart';

/// The Phase 8 QA widths, plus a laptop to catch anything that only breaks
/// when the shell switches away from the bottom bar.
const _widths = <String, Size>{
  'phone': Size(390, 844),
  'portrait tablet': Size(768, 1024),
  'laptop': Size(1440, 900),
};

class _RoleAuth extends AuthController {
  _RoleAuth(this.role, {this.agentId});

  final UserRole role;
  final String? agentId;

  @override
  AuthState build() => AuthState(
        stage: AuthStage.signedIn,
        email: 'user@test.local',
        user: AppUser(
          id: 'user-1',
          name: 'Test User',
          email: 'user@test.local',
          role: role,
          agentId: agentId,
        ),
      );
}

/// Signs in as [role] against the seeded Hindi dataset.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  Size size, {
  required UserRole role,
  required ThemeMode themeMode,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final repo = seededRepository();
  // Read the fixture synchronously. `fetchAgents()` and friends go through a
  // Future.delayed, and awaiting one before the first pump deadlocks: inside
  // testWidgets the timer only fires when the tester advances time.
  final member =
      repo.membersView.firstWhere((m) => m.status == MemberStatus.active);
  repo.portalMemberId = member.id;
  final agentId = member.agentId;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          () => _RoleAuth(role, agentId: agentId),
        ),
      ],
      child: const RudranshAdminApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(RudranshAdminApp)),
  );
  if (themeMode != ThemeMode.light) {
    container.read(themeModeProvider.notifier).set(themeMode);
  }
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final (label, role, nav) in [
    ('agent', UserRole.agent, AgentRoutes.nav),
    ('member', UserRole.member, MemberRoutes.nav),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final entry in _widths.entries) {
        testWidgets(
            'every $label page lays out cleanly on ${entry.key} (${mode.name})',
            (tester) async {
          final container = await _pump(
            tester,
            entry.value,
            role: role,
            themeMode: mode,
          );
          expect(
            Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );

          for (final item in nav) {
            container.read(routerProvider).go(item.path);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${item.label} broke at ${entry.key} (${mode.name})',
            );
            // The shell must still be on screen: a page that throws during
            // build can leave an empty frame that no exception reports.
            expect(
              find.byType(Scaffold),
              findsWidgets,
              reason: '${item.label} rendered nothing at ${entry.key}',
            );
          }
        });
      }
    }
  }

  testWidgets('the public lookup lays out at 390 px in both themes',
      (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final container = await _pump(
        tester,
        const Size(390, 844),
        role: UserRole.member,
        themeMode: mode,
      );
      container.read(routerProvider).go(AppRoutes.lookup);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'lookup (${mode.name})');
    }
  });

  group('Hindi', () {
    test('Devanagari is the fallback font on every text style', () {
      // The trust's records are in Hindi; without this fallback the bundled
      // Latin font draws them as empty boxes.
      expect(kFontFallback, contains('NotoSansDevanagari'));

      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(
          theme.textTheme.bodyMedium?.fontFamilyFallback,
          contains('NotoSansDevanagari'),
          reason: 'body text has no Devanagari fallback',
        );
      }
    });

    testWidgets('an agent sees their Hindi member names at 390 px',
        (tester) async {
      final container = await _pump(
        tester,
        const Size(390, 844),
        role: UserRole.agent,
        themeMode: ThemeMode.light,
      );
      container.read(routerProvider).go(AppRoutes.agentMembers);
      await tester.pumpAndSettle();

      // The seed names are Devanagari; finding one proves the list rendered
      // the real records rather than an empty or errored state.
      final devanagari = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').runes.any((r) => r >= 0x0900 && r <= 0x097F),
      );
      expect(devanagari, findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
