import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/utils/formatters.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'support/seed_data.dart';

/// A repository with no artificial latency so tests settle quickly.
InMemoryTrustRepository _fastRepo() =>
    seededRepository();

class _AdminAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
        stage: AuthStage.signedIn,
        email: 'admin@test.local',
        user: AppUser(
          id: 'admin-test',
          name: 'Test Admin',
          email: 'admin@test.local',
          role: UserRole.owner,
        ),
      );
}

void main() {
  group('InMemoryTrustRepository', () {
    test('seeds yojnas, members, agents and payments', () async {
      final repo = _fastRepo();
      expect((await repo.fetchYojnas()).length, 3);
      expect((await repo.fetchMembers()).length, greaterThan(100));
      expect((await repo.fetchAgents()), isNotEmpty);
      expect((await repo.fetchPayments()), isNotEmpty);
    });

    test('nextRegNo increments within a scheme', () async {
      final repo = _fastRepo();
      final yojna = (await repo.fetchYojnas()).first;
      final first = await repo.nextRegNo(yojna.id);

      await repo.createMember(
        Member(
          id: 'test-1',
          yojnaId: yojna.id,
          regNo: first,
          name: 'परीक्षण सदस्य',
          fatherOrHusbandName: 'पिता',
          jati: 'सुथार',
          warisName: 'वारिस',
          warisRelation: 'पुत्र',
          primaryPhone: '9876543210',
          aadhaar: '123456789012',
          joinDate: DateTime.now(),
        ),
      );

      final second = await repo.nextRegNo(yojna.id);
      expect(second, isNot(first));
      expect(int.parse(second.split('-').last),
          int.parse(first.split('-').last) + 1);
    });

    test('findMemberByPhone matches primary and alternate numbers', () async {
      final repo = _fastRepo();
      final member = (await repo.fetchMembers())
          .firstWhere((m) => m.altPhone.isNotEmpty);

      expect((await repo.findMemberByPhone(member.primaryPhone))?.id,
          member.id);
      expect((await repo.findMemberByPhone(member.altPhone))?.id, member.id);
      expect(await repo.findMemberByPhone('0000000000'), isNull);
    });

    test('creating a closing case keeps the member active', () async {
      final repo = _fastRepo();
      final member =
          (await repo.fetchMembers()).firstWhere((m) => !m.isClosed);

      await repo.createClosingCase(
        ClosingCase(
          id: 'case-1',
          memberId: member.id,
          yojnaId: member.yojnaId,
          closingDate: DateTime.now(),
          closingGroup: 'Group-99',
          claimAmount: 100000,
        ),
      );

      final updated =
          (await repo.fetchMembers()).firstWhere((m) => m.id == member.id);
      expect(updated.status, member.status);
      expect(updated.closingGroup, 'Group-99');
    });

    test('deleting an agent unassigns their members', () async {
      final repo = _fastRepo();
      final agent = (await repo.fetchAgents()).first;
      await repo.deleteAgent(agent.id);

      final members = await repo.fetchMembers();
      expect(members.where((m) => m.agentId == agent.id), isEmpty);
    });
  });

  group('Validators and formatting', () {
    test('phone accepts 10-digit Indian numbers only', () {
      expect(Fmt.phone('9876543210'), '98765 43210');
      expect(Fmt.aadhaarMasked('123456789012'), 'XXXX XXXX 9012');
    });
  });

  testWidgets('admin shell renders the dashboard', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1500, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(_fastRepo()),
          authControllerProvider.overrideWith(_AdminAuth.new),
        ],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(S.appName), findsOneWidget);
    expect(find.text(S.totalMembers), findsOneWidget);
    expect(find.text(S.closedCases), findsOneWidget);
    expect(find.byTooltip(S.add), findsOneWidget);
  });

  testWidgets('narrow layout swaps the sidebar for a drawer', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(_fastRepo()),
          authControllerProvider.overrideWith(_AdminAuth.new),
        ],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Sidebar is hidden behind the drawer at this width.
    expect(find.text(S.mainMenu), findsNothing);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text(S.mainMenu), findsOneWidget);
  });
}
