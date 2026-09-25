import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/agent_repository.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'support/seed_data.dart';

class _AgentAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
        stage: AuthStage.signedIn,
        email: 'agent@test.local',
        user: AppUser(
          id: 'user-agent',
          name: 'Field Agent',
          email: 'agent@test.local',
          role: UserRole.agent,
        ),
      );
}

void main() {
  group('InMemoryAgentRepository', () {
    late InMemoryTrustRepository base;
    late InMemoryAgentRepository agent;

    setUp(() {
      base = seededRepository();
      agent = InMemoryAgentRepository(base);
    });

    Future<Member> addPending() async {
      final yojna = (await agent.fetchMyYojnas()).first;
      await agent.addMember(
        Member(
          id: '',
          yojnaId: yojna.id,
          regNo: 'IGNORED',
          name: 'Field Signup',
          fatherOrHusbandName: 'Father',
          jati: '',
          warisName: 'Nominee',
          warisRelation: 'Wife',
          primaryPhone: '9400000001',
          aadhaar: '',
          joinDate: DateTime.now(),
        ),
      );
      final page = await agent.fetchMyMembers(
        text: 'field signup',
        offset: 0,
        limit: 5,
      );
      return page.items.single;
    }

    test('members an agent adds wait for approval', () async {
      final member = await addPending();
      expect(member.status, MemberStatus.pending);
      expect(member.regNo, isEmpty);
      expect((await base.fetchPendingMembers()).map((m) => m.id), [member.id]);
      expect((await agent.fetchSummary()).pendingMembers, 1);
    });

    test('an agent sees only their own members, without Aadhaar', () async {
      final me = (await base.fetchAgents()).firstWhere((a) => a.isActive);
      final page = await agent.fetchMyMembers(offset: 0, limit: 500);
      expect(page.items, isNotEmpty);
      expect(page.items.every((m) => m.agentId == null || m.agentId == me.id), isTrue);
      expect(page.items.every((m) => m.aadhaar.isEmpty), isTrue);
    });

    test('payments are pending; before approval only the registration fee',
        () async {
      final member = await addPending();
      Payment payment(PaymentKind kind) => Payment(
            id: '',
            receiptNo: '',
            memberId: member.id,
            yojnaId: member.yojnaId,
            amount: 50,
            date: DateTime.now(),
            kind: kind,
          );

      await expectLater(
        agent.recordPayment(payment(PaymentKind.contribution)),
        throwsA(isA<RepositoryException>()),
      );
      final receiptNo = await agent.recordPayment(payment(PaymentKind.registration));
      expect(receiptNo, startsWith('RCP-'));

      final mine = await agent.fetchMyPayments(offset: 0, limit: 5);
      final recorded = mine.items.firstWhere((p) => p.receiptNo == receiptNo);
      expect(recorded.status, PaymentStatus.pending);
      expect(recorded.source, PaymentSource.agent);
      expect(mine.members[member.id]?.name, 'Field Signup');

      // The office sees it in the approval queue.
      final queue = await base.fetchPendingPayments();
      expect(queue.items.map((p) => p.receiptNo), contains(receiptNo));

      await agent.requestCancel(recorded.id, 'Wrong amount');
      await expectLater(
        agent.requestCancel(recorded.id, 'Again'),
        throwsA(isA<RepositoryException>()),
      );
      expect((await base.fetchCancelRequests()).items.single.id, recorded.id);
    });
  });

  for (final (path, marker) in [
    (AppRoutes.agentHome, S.approvedThisMonth),
    (AppRoutes.agentMembers, S.myMembersSub),
    (AppRoutes.agentCollections, 'Receipts you issued'),
  ]) {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets('$path lays out at ${size.width.toInt()} px', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(
                seededRepository(),
              ),
              authControllerProvider.overrideWith(_AgentAuth.new),
            ],
            child: const RudranshAdminApp(),
          ),
        );
        await tester.pumpAndSettle();
        ProviderScope.containerOf(tester.element(find.byType(RudranshAdminApp)))
            .read(routerProvider)
            .go(path);
        await tester.pumpAndSettle();

        expect(find.text(marker), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the record payment form opens from the home page', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            seededRepository(),
          ),
          authControllerProvider.overrideWith(_AgentAuth.new),
        ],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.recordPayment));
    await tester.pumpAndSettle();
    expect(find.text('Name, reg no or phone'), findsOneWidget);

    // Saving without a member is refused.
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    expect(find.text('Select a member'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The office's member menu, cut to what an agent may do.
  testWidgets('an agent''s member menu has no office-only actions',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(seededRepository()),
          authControllerProvider.overrideWith(_AgentAuth.new),
        ],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(RudranshAdminApp)))
        .read(routerProvider)
        .go(AppRoutes.agentMembers);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(S.actions).first);
    await tester.pumpAndSettle();
    for (final item in [S.view, S.editContact, S.inviteToApp]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    for (final item in [S.delete, S.eraseData, S.exportData, S.edit]) {
      expect(find.text(item), findsNothing, reason: item);
    }

    // Edit contact carries the member's email.
    await tester.tap(find.text(S.editContact));
    await tester.pumpAndSettle();
    expect(find.text(S.fldMemberEmail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
