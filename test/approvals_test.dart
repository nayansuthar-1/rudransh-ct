import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'support/seed_data.dart';

InMemoryTrustRepository _repo() =>
    seededRepository();

/// An agent's sign-up plus its registration fee, both waiting for approval.
Future<(Member, Payment)> _agentSubmission(InMemoryTrustRepository repo) async {
  final yojna = (await repo.fetchYojnas()).first;
  final agent = (await repo.fetchAgents()).first;
  final member = await repo.createMember(
    Member(
      id: '',
      yojnaId: yojna.id,
      regNo: '',
      name: 'Pending Person',
      fatherOrHusbandName: 'Father',
      jati: '',
      warisName: 'Nominee',
      warisRelation: 'Son',
      primaryPhone: '9500000001',
      aadhaar: '',
      agentId: agent.id,
      joinDate: DateTime.now(),
      status: MemberStatus.pending,
    ),
  );
  final payment = await repo.createPayment(
    Payment(
      id: '',
      receiptNo: await repo.nextReceiptNo(),
      memberId: member.id,
      yojnaId: yojna.id,
      amount: 50,
      date: DateTime.now(),
      status: PaymentStatus.pending,
      kind: PaymentKind.registration,
      agentId: agent.id,
      source: PaymentSource.agent,
    ),
  );
  return (member, payment);
}

void main() {
  group('approvals in the in-memory repository', () {
    test('pending members do not count and get a number on approval', () async {
      final repo = _repo();
      final before = (await repo.fetchDashboardStats(null)).totalMembers;
      final (member, payment) = await _agentSubmission(repo);

      expect((await repo.fetchDashboardStats(null)).totalMembers, before);
      expect((await repo.fetchPendingMembers()).map((m) => m.id), [member.id]);

      await expectLater(
        repo.approvePayment(payment.id),
        throwsA(isA<RepositoryException>()
            .having((e) => e.message, 'message', 'Approve the member first.')),
      );

      final regNo = await repo.approveMember(member.id);
      expect(regNo, isNotEmpty);
      expect((await repo.fetchDashboardStats(null)).totalMembers, before + 1);

      await repo.approvePayment(payment.id);
      expect((await repo.fetchPendingPayments()).items, isEmpty);
    });

    test('rejecting a member keeps it inactive and fails its payments', () async {
      final repo = _repo();
      final (member, payment) = await _agentSubmission(repo);

      await expectLater(
        repo.rejectMember(member.id, '  '),
        throwsA(isA<RepositoryException>()),
      );
      await repo.rejectMember(member.id, 'Duplicate');

      final after = (await repo.fetchMembersByIds([member.id])).single;
      expect(after.status, MemberStatus.inactive);
      expect(after.reviewNote, 'Duplicate');
      final failed = (await repo.fetchPayments()).firstWhere((p) => p.id == payment.id);
      expect(failed.status, PaymentStatus.failed);
      expect(failed.rejectReason, contains('Duplicate'));
    });

    test('a cancelled receipt leaves the totals', () async {
      final repo = _repo();
      final (member, payment) = await _agentSubmission(repo);
      await repo.approveMember(member.id);
      await repo.approvePayment(payment.id);

      final query = PaymentQuery(memberId: member.id);
      expect((await repo.fetchPaymentTotals(query)).paid, 50);

      await repo.cancelPayment(payment.id, 'Wrong member');
      expect((await repo.fetchPaymentTotals(query)).paid, 0);
      await expectLater(
        repo.cancelPayment(payment.id, 'Again'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('reassigning moves every member of an agent', () async {
      final repo = _repo();
      final agents = (await repo.fetchAgents()).where((a) => a.isActive).toList();
      final from = agents[0];
      final to = agents[1];
      final count = (await repo.fetchMemberCountByAgent())[from.id] ?? 0;

      final moved = await repo.reassignMembers(from.id, to.id);
      expect(moved, greaterThanOrEqualTo(count));
      expect((await repo.fetchMemberCountByAgent())[from.id], isNull);
      await expectLater(
        repo.reassignMembers(to.id, to.id),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  testWidgets('the approvals page approves a new member', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    final repo = _repo();
    // Real async: the repository's Future.delayed never fires on the fake clock.
    final (member, _) = (await tester.runAsync(() => _agentSubmission(repo)))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(RudranshAdminApp)))
        .read(routerProvider)
        .go(AppRoutes.approvals);
    await tester.pumpAndSettle();

    expect(find.text('${S.newMembers} (1)'), findsOneWidget);
    expect(find.text('${S.paymentsToApprove} (1)'), findsOneWidget);
    expect(find.text(member.name), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, S.approve).first);
    await tester.pumpAndSettle();

    expect(find.text('${S.newMembers} (1)'), findsNothing);
    expect(await tester.runAsync(repo.fetchPendingMembers), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
