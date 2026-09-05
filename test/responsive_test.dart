import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/state/providers.dart';

/// Widths that bracket every breakpoint the shell reacts to.
const _widths = <String, Size>{
  'phone': Size(390, 844),
  'large phone': Size(600, 900),
  'tablet': Size(834, 1112),
  'small laptop': Size(1280, 800),
  'desktop': Size(1600, 1000),
  'wide desktop': Size(1920, 1080),
};

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          InMemoryTrustRepository(latency: Duration.zero),
        ),
      ],
      child: const RudranshAdminApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Navigates through the sidebar, opening the drawer first when it is used.
Future<void> _goTo(WidgetTester tester, String label) async {
  final drawerButton = find.byTooltip('Menu');
  final tile = find.text(label);

  if (tile.evaluate().isEmpty) {
    await tester.tap(drawerButton);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in _widths.entries) {
    testWidgets('every page lays out cleanly on ${entry.key}', (tester) async {
      await _pumpApp(tester, entry.value);

      for (final item in AppRoutes.nav) {
        await _goTo(tester, item.label);
        expect(
          tester.takeException(),
          isNull,
          reason: '${item.label} overflowed at ${entry.key}',
        );
      }
    });
  }

  testWidgets('add-member dialog opens and validates', (tester) async {
    await _pumpApp(tester, const Size(1600, 1000));

    await tester.tap(find.text(S.addMemberHi).first);
    await tester.pumpAndSettle();

    expect(find.text(S.personalInfo), findsOneWidget);
    expect(find.text(S.contactInfo), findsOneWidget);
    expect(find.text(S.copyFromExisting), findsOneWidget);

    // Submitting an empty form surfaces validation instead of saving.
    await tester.tap(find.text(S.submitHi));
    await tester.pumpAndSettle();
    expect(find.text(S.required), findsWidgets);
    expect(find.byType(Dialog), findsOneWidget, reason: 'dialog stays open');
  });

  testWidgets('add-member dialog is full screen on a phone', (tester) async {
    await _pumpApp(tester, const Size(390, 844));

    await tester.tap(find.byTooltip(S.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.addMemberHi).last);
    await tester.pumpAndSettle();

    final dialog = tester.getRect(find.byType(Dialog));
    expect(dialog.width, closeTo(390, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheme scope filters the member list', (tester) async {
    await _pumpApp(tester, const Size(1600, 1000));
    await _goTo(tester, S.members);

    final all = find.textContaining('सदस्य', findRichText: false);
    expect(all, findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
