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

import 'support/signed_in.dart';

/// The same money as `supabase/tests/commission_test.sql`, in memory.
///
/// Agent A collects at 10%. This month: 100 and 200 cash, 300 UPI, 400 cash
/// still pending, 500 cash cancelled, 600 cash registration, a 5,000 claim
/// payout. Last month: 1,000 cash.
///
/// So cash in hand = 100 + 200 + 600 + 5000 + 1000 = 6,900; this month's
/// commission base = 100 + 200 + 300 + 600 = 1,200, at 10% = 120; last
/// month's base = 1,000, at 10% = 100.
class _Scenario {
  _Scenario._(this.base, this.me, this.other, this.agent, this.agentB);

  final InMemoryTrustRepository base;
  final Agent me;
  final Agent other;
  final InMemoryAgentRepository agent;
  final InMemoryAgentRepository agentB;

  static const cashInHand = 6900.0;
  static const monthCommission = 120.0;

  static DateTime get thisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// An empty repository, not the seeded one: the seed's own receipts would
  /// land in the totals under test.
  static Future<_Scenario> build() async {
    final base = InMemoryTrustRepository(latency: Duration.zero);

    Future<Agent> agent(String name, double percent) => base.createAgent(
          Agent(
            id: '',
            code: '',
            name: name,
            phone: '9500000001',
            commissionPercent: percent,
            joinDate: DateTime.now(),
          ),
        );
    final me = await agent('Comm Agent A', 10);
    final other = await agent('Comm Agent B', 5);

    final yojna = await base.createYojna(
      Yojna(
        id: '',
        name: 'Commission Test Yojna',
        code: 'CTY',
        contributionAmount: 100,
        claimAmount: 50000,
        createdAt: DateTime.now(),
      ),
    );
    final member = await base.createMember(
      Member(
        id: '',
        yojnaId: yojna.id,
        regNo: 'CTY-1',
        name: 'Commission M1',
        fatherOrHusbandName: 'Father',
        jati: '',
        warisName: 'Nominee',
        warisRelation: 'Son',
        primaryPhone: '9600000001',
        aadhaar: '',
        agentId: me.id,
        joinDate: DateTime.now().subtract(const Duration(days: 400)),
      ),
    );

    // The first of the month is always a valid payment date.
    final first = thisMonth;
    final lastMonth = DateTime(first.year, first.month - 1);

    Future<Payment> pay(
      double amount, {
      PaymentMode mode = PaymentMode.cash,
      PaymentStatus status = PaymentStatus.paid,
      PaymentKind kind = PaymentKind.contribution,
      DateTime? date,
    }) async =>
        base.createPayment(
          Payment(
            id: '',
            receiptNo: await base.nextReceiptNo(),
            memberId: member.id,
            yojnaId: yojna.id,
            agentId: me.id,
            amount: amount,
            date: date ?? first,
            mode: mode,
            status: status,
            kind: kind,
          ),
        );

    await pay(100);
    await pay(200);
    await pay(300, mode: PaymentMode.upi);
    await pay(400, status: PaymentStatus.pending);
    final cancelled = await pay(500);
    await base.cancelPayment(cancelled.id, 'Test');
    await pay(600, kind: PaymentKind.registration);
    await pay(5000, kind: PaymentKind.closingPayout);
    await pay(1000, date: lastMonth);

    return _Scenario._(
      base,
      me,
      other,
      InMemoryAgentRepository(base, agentId: me.id),
      InMemoryAgentRepository(base, agentId: other.id),
    );
  }
}

class _AgentAuth extends AuthController {
  _AgentAuth(this.agentId);

  final String? agentId;

  @override
  AuthState build() => AuthState(
        stage: AuthStage.signedIn,
        email: 'agent@test.local',
        user: AppUser(
          id: 'user-agent',
          name: 'Field Agent',
          email: 'agent@test.local',
          role: UserRole.agent,
          agentId: agentId,
        ),
      );
}

/// Staff may confirm a handover but never pay commission (§11.3).
class _StaffAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
        stage: AuthStage.signedIn,
        email: 'staff@test.local',
        user: AppUser(
          id: 'user-staff',
          name: 'Office Staff',
          email: 'staff@test.local',
          role: UserRole.staff,
        ),
      );
}

Matcher _throwsMessage(String text) => throwsA(
      isA<RepositoryException>()
          .having((e) => e.message, 'message', contains(text)),
    );

void main() {
  group('cash in hand', () {
    test('counts approved, uncancelled cash the agent still holds', () async {
      final s = await _Scenario.build();
      final summary = await s.agent.fetchSummary();

      expect(summary.cashInHand, _Scenario.cashInHand);
      expect(summary.monthCommission, _Scenario.monthCommission);
      expect(summary.handoverWaiting, 0);

      // The declare form lists the same money, receipt by receipt.
      final open = await s.agent.fetchOpenCash();
      expect(open, hasLength(5), reason: 'UPI, pending and cancelled are out');
      expect(
        open.fold<double>(0, (sum, r) => sum + r.amount),
        _Scenario.cashInHand,
      );
    });

    test('declaring moves it out of the hand and into the queue', () async {
      final s = await _Scenario.build();

      expect(await s.agent.declareHandover(), _Scenario.cashInHand);
      final after = await s.agent.fetchSummary();
      expect(after.cashInHand, 0);
      expect(after.handoverWaiting, _Scenario.cashInHand);
      expect(await s.agent.fetchOpenCash(), isEmpty);

      final mine = await s.agent.fetchMyHandovers();
      expect(mine.single.receiptCount, 5);
      expect(mine.single.status, RequestStatus.pending);

      // Nothing open, so there is nothing to declare twice.
      await expectLater(
        s.agent.declareHandover(),
        _throwsMessage('no cash waiting'),
      );
    });

    test('an agent cannot declare another agent\'s receipts', () async {
      final s = await _Scenario.build();
      final mine = await s.agent.fetchOpenCash();

      expect((await s.agentB.fetchSummary()).cashInHand, 0);
      expect(await s.agentB.fetchOpenCash(), isEmpty);
      await expectLater(
        s.agentB.declareHandover(paymentIds: [for (final r in mine) r.id]),
        _throwsMessage('no cash waiting'),
      );
    });

    test('part of it can be declared, and the rest stays in hand', () async {
      final s = await _Scenario.build();
      final open = await s.agent.fetchOpenCash()
        ..sort((a, b) => a.amount.compareTo(b.amount));
      final two = [open[0].id, open[1].id];

      expect(await s.agent.declareHandover(paymentIds: two), 300);
      expect((await s.agent.fetchSummary()).cashInHand, 6600);

      // A receipt already in a handover cannot go into a second one.
      await expectLater(
        s.agent.declareHandover(paymentIds: two),
        _throwsMessage('no cash waiting'),
      );
    });
  });

  group('the office decides', () {
    test('rejecting sends the money back to the agent', () async {
      final s = await _Scenario.build();
      await s.agent.declareHandover();

      final queued = (await s.base.fetchPendingHandovers()).single;
      expect(queued.amount, _Scenario.cashInHand);
      expect(queued.receiptCount, 5);
      expect(queued.agentName, s.me.name);

      await expectLater(
        s.base.rejectHandover(queued.id, '   '),
        _throwsMessage('Give a reason'),
      );
      await s.base.rejectHandover(queued.id, 'Short by 100');

      expect(await s.base.fetchPendingHandovers(), isEmpty);
      expect((await s.agent.fetchSummary()).cashInHand, _Scenario.cashInHand);

      final mine = (await s.agent.fetchMyHandovers()).single;
      expect(mine.status, RequestStatus.rejected);
      expect(mine.decisionNote, 'Short by 100');

      // And it cannot be decided twice.
      await expectLater(
        s.base.confirmHandover(queued.id),
        _throwsMessage('no longer waiting'),
      );
    });

    test('confirming keeps the money out of the hand', () async {
      final s = await _Scenario.build();
      await s.agent.declareHandover();
      final queued = (await s.base.fetchPendingHandovers()).single;

      await s.base.confirmHandover(queued.id);
      expect(await s.base.fetchPendingHandovers(), isEmpty);
      expect((await s.agent.fetchSummary()).cashInHand, 0);
      expect((await s.agent.fetchSummary()).handoverWaiting, 0);
      expect(
        (await s.agent.fetchMyHandovers()).single.status,
        RequestStatus.approved,
      );
    });
  });

  group('commission', () {
    test('is the percentage of what was approved that month', () async {
      final s = await _Scenario.build();
      final months = await s.agent.fetchMyCommission();

      expect(months, hasLength(6));
      expect(months.first.month, _Scenario.thisMonth);
      expect(months.first.collected, 1200, reason: 'the claim payout is out');
      expect(months.first.amount, _Scenario.monthCommission);
      expect(months.first.isPaid, isFalse);
      expect(months[1].amount, 100, reason: 'last month, 1,000 at 10%');
    });

    test('the report covers every agent, and paying it can be corrected',
        () async {
      final s = await _Scenario.build();
      final month = _Scenario.thisMonth;

      var report = await s.base.fetchCommissionReport(month);
      expect(report.map((r) => r.agentId), contains(s.other.id),
          reason: 'an agent who collected nothing is still listed');
      var mine = report.singleWhere((r) => r.agentId == s.me.id);
      expect(mine.collected, 1200);
      expect(mine.amount, _Scenario.monthCommission);
      expect(mine.isPaid, isFalse);

      // No amount means the calculated one.
      await s.base.markCommissionPaid(agentId: s.me.id, month: month);
      report = await s.base.fetchCommissionReport(month);
      mine = report.singleWhere((r) => r.agentId == s.me.id);
      expect(mine.paidAmount, _Scenario.monthCommission);
      expect(mine.isPaid, isTrue);
      expect(mine.differs, isFalse);

      // Paying the same month again corrects it rather than failing.
      await s.base.markCommissionPaid(
        agentId: s.me.id,
        month: month,
        amount: 150,
        reference: 'Cash',
      );
      mine = (await s.base.fetchCommissionReport(month))
          .singleWhere((r) => r.agentId == s.me.id);
      expect(mine.paidAmount, 150);
      expect(mine.amount, _Scenario.monthCommission,
          reason: 'what is owed is unchanged');
      expect(mine.differs, isTrue);
      expect(mine.reference, 'Cash');

      // The agent's own view agrees with the report.
      expect((await s.agent.fetchMyCommission()).first.paidAmount, 150);
    });

    test('a month that has not started cannot be paid', () async {
      final s = await _Scenario.build();
      final next = DateTime(_Scenario.thisMonth.year,
          _Scenario.thisMonth.month + 1);
      await expectLater(
        s.base.markCommissionPaid(agentId: s.me.id, month: next),
        _throwsMessage('has not started'),
      );
    });
  });

  group('notifications', () {
    test('the agent hears about both decisions', () async {
      final s = await _Scenario.build();
      await s.agent.declareHandover();
      final first = (await s.base.fetchPendingHandovers()).single;
      await s.base.rejectHandover(first.id, 'Short by 100');

      await s.agent.declareHandover();
      final second = (await s.base.fetchPendingHandovers()).single;
      await s.base.confirmHandover(second.id);
      await s.base.markCommissionPaid(
        agentId: s.me.id,
        month: _Scenario.thisMonth,
      );

      final kinds =
          (await s.base.fetchNotifications()).map((n) => n.kind).toList();
      expect(kinds, contains(NotificationKind.handoverRejected));
      expect(kinds, contains(NotificationKind.handoverConfirmed));
      expect(kinds, contains(NotificationKind.commissionPaid));

      final rejected = (await s.base.fetchNotifications())
          .firstWhere((n) => n.kind == NotificationKind.handoverRejected);
      expect(rejected.body, 'Short by 100');
      expect(rejected.link, AppRoutes.agentCollections);
    });
  });

  group('screens', () {
    /// Signs in as the owner unless [auth] says otherwise.
    Future<(ProviderContainer, _Scenario)> pump(
      WidgetTester tester,
      Size size, {
      AuthController Function()? auth,
      _Scenario? scenario,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final s = scenario ?? (await tester.runAsync(_Scenario.build))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(s.base),
            if (auth != null)
              authControllerProvider.overrideWith(auth)
            else
              signedInAs(UserRole.owner),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (
        ProviderScope.containerOf(tester.element(find.byType(RudranshAdminApp))),
        s,
      );
    }

    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      final width = size.width.toInt();

      testWidgets('the agent sees cash and commission at $width px',
          (tester) async {
        final s = (await tester.runAsync(_Scenario.build))!;
        final (container, _) = await pump(
          tester,
          size,
          scenario: s,
          auth: () => _AgentAuth(s.me.id),
        );
        container.read(routerProvider).go(AppRoutes.agentHome);
        await tester.pumpAndSettle();
        expect(find.text(S.cashInHand), findsWidgets);
        expect(find.text(S.thisMonthCommission), findsOneWidget);
        expect(tester.takeException(), isNull);

        container.read(routerProvider).go(AppRoutes.agentCollections);
        await tester.pumpAndSettle();
        expect(find.text(S.myCommission), findsOneWidget);
        expect(find.widgetWithText(FilledButton, S.handover), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the owner sees the commission report at $width px',
          (tester) async {
        final (container, _) = await pump(tester, size);
        container.read(routerProvider).go(AppRoutes.commission);
        await tester.pumpAndSettle();

        expect(find.text(S.commission), findsWidgets);
        expect(find.text('Commission owed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the handover reaches the approvals queue', (tester) async {
      final s = (await tester.runAsync(_Scenario.build))!;
      await tester.runAsync(s.agent.declareHandover);

      final (container, _) = await pump(
        tester,
        const Size(1440, 900),
        scenario: s,
      );
      container.read(routerProvider).go(AppRoutes.approvals);
      await tester.pumpAndSettle();

      expect(find.text('${S.handovers} (1)'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, S.confirmHandover),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, S.confirmHandover));
      await tester.pumpAndSettle();
      expect(find.text('${S.handovers} (1)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff see the report but cannot mark it paid', (tester) async {
      await pump(
        tester,
        const Size(1440, 900),
        auth: _StaffAuth.new,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RudranshAdminApp)),
      );
      container.read(routerProvider).go(AppRoutes.commission);
      await tester.pumpAndSettle();

      expect(find.text(S.ownerOnlyCommission), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, S.markCommissionPaid),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
