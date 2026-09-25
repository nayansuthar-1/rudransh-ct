import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/core/utils/whatsapp.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/agent_repository.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:rudransh_ct/data/repositories/upload_repository.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'support/seed_data.dart';
import 'support/signed_in.dart';

/// The same closing group as `supabase/tests/dues_test.sql`, in memory.
///
/// Group T-1 in a fresh Yojna: deaths of D1 (200 days ago) and D2 (190 days
/// ago). M1 paid, M2 owes, M3 belongs to another agent and owes, M4 joined
/// after the closing, M5 is inactive.
class _Scenario {
  _Scenario._(this.base, this.me, this.agent, this.ids);

  final InMemoryTrustRepository base;
  final Agent me;
  final InMemoryAgentRepository agent;
  final Map<String, String> ids;

  static const group = 'T-1';

  String get yojnaId => ids['yojna']!;
  String get firstCase => ids['c1']!;

  static Future<_Scenario> build() async {
    final base = seededRepository();
    final agents = (await base.fetchAgents()).where((a) => a.isActive).toList();
    final me = agents[0];
    final other = agents[1];
    final now = DateTime.now();
    DateTime daysAgo(int n) => now.subtract(Duration(days: n));

    final yojna = await base.createYojna(
      Yojna(
        id: '',
        name: 'Dues Test Yojna',
        code: 'DTY',
        contributionAmount: 100,
        claimAmount: 50000,
        createdAt: now,
      ),
    );
    final ids = <String, String>{'yojna': yojna.id};

    Future<void> member(
      String key, {
      required Agent agent,
      required int joinedDaysAgo,
      MemberStatus status = MemberStatus.active,
    }) async {
      final m = await base.createMember(
        Member(
          id: '',
          yojnaId: yojna.id,
          regNo: 'DTY-$key',
          name: 'Dues $key',
          fatherOrHusbandName: 'Father',
          jati: '',
          warisName: 'Nominee $key',
          warisRelation: 'Son',
          primaryPhone: '98000000${ids.length.toString().padLeft(2, '0')}',
          aadhaar: '',
          agentId: agent.id,
          joinDate: daysAgo(joinedDaysAgo),
          status: status,
        ),
      );
      ids[key] = m.id;
    }

    await member('M1', agent: me, joinedDaysAgo: 400);
    await member('M2', agent: me, joinedDaysAgo: 400);
    await member('M3', agent: other, joinedDaysAgo: 400);
    await member('M4', agent: me, joinedDaysAgo: 100);
    await member('M5', agent: me, joinedDaysAgo: 400, status: MemberStatus.inactive);
    await member('D1', agent: me, joinedDaysAgo: 900);
    await member('D2', agent: other, joinedDaysAgo: 900);

    for (final (key, died, days) in [('c1', 'D1', 200), ('c2', 'D2', 190)]) {
      final c = await base.createClosingCase(
        ClosingCase(
          id: '',
          memberId: ids[died]!,
          yojnaId: yojna.id,
          closingDate: daysAgo(days),
          closingGroup: group,
          claimAmount: 50000,
        ),
      );
      ids[key] = c.id;
    }

    // The office's receipt for M1, linked to the group's second case.
    await base.createPayment(
      Payment(
        id: '',
        receiptNo: await base.nextReceiptNo(),
        memberId: ids['M1']!,
        yojnaId: yojna.id,
        amount: 100,
        date: now,
        closingCaseId: ids['c2'],
      ),
    );

    return _Scenario._(
      base,
      me,
      InMemoryAgentRepository(base, agentId: me.id),
      ids,
    );
  }

  Future<ClosingGroupDues> myGroup() async {
    final page = await agent.fetchClosingGroups(offset: 0, limit: 100);
    return page.items.singleWhere((g) => g.yojnaId == yojnaId);
  }

  Payment contribution(String member, {String? closing}) => Payment(
        id: '',
        receiptNo: '',
        memberId: ids[member]!,
        yojnaId: yojnaId,
        amount: 100,
        date: DateTime.now(),
        closingCaseId: closing ?? firstCase,
      );
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

Matcher _throwsMessage(String text) => throwsA(
      isA<RepositoryException>().having((e) => e.message, 'message', contains(text)),
    );

void main() {
  group('WhatsApp links', () {
    test('only 10-digit Indian numbers get a link', () {
      final uri = WhatsApp.link('98765 43210', 'नमस्ते');
      expect(uri.toString(), startsWith('https://wa.me/919876543210?text='));
      expect(uri!.queryParameters['text'], 'नमस्ते');
      expect(WhatsApp.link('+91 98765-43210', 'x')?.path, '/919876543210');
      expect(WhatsApp.link('12345', 'x'), isNull);
      expect(WhatsApp.link('', 'x'), isNull);
    });

    test('the receipt message has the receipt, amount and closing', () {
      final text = WhatsApp.receiptMessage(
        memberName: 'Ramesh',
        payment: Payment(
          id: 'p',
          receiptNo: 'RCP-1234',
          memberId: 'm',
          yojnaId: 'y',
          amount: 1500,
          date: DateTime(2026, 10, 16),
          status: PaymentStatus.pending,
          closingGroup: 'Group-14',
        ),
      );
      expect(text, contains('Ramesh'));
      expect(text, contains('RCP-1234'));
      expect(text, contains('₹1,500'));
      expect(text, contains('Group-14'));
      expect(text, contains('16-10-2026'));
      expect(text, contains('स्वीकृति के बाद'));
    });

    test('the reminder asks for what is still to collect', () {
      final text = WhatsApp.duesReminder(
        due: MemberDue(
          memberId: 'm',
          yojnaId: 'y',
          closingCaseId: 'c',
          closingGroup: 'Group-14',
          closingDate: DateTime(2026, 9, 1),
          amount: 500,
          paid: 200,
          memberName: 'Sita',
          regNo: 'SSY-2026-0001',
        ),
        yojnaName: 'Samaj Suraksha',
        agentName: 'Field Agent',
      );
      expect(text, contains('Sita'));
      expect(text, contains('₹300'));
      expect(text, contains('SSY-2026-0001'));
      expect(text, contains('– Field Agent'));
    });
  });

  group('dues in memory (same count as dues_test.sql)', () {
    test('the group lists who owes, per agent', () async {
      final s = await _Scenario.build();

      final g = await s.myGroup();
      expect(g.closingGroup, _Scenario.group);
      expect(g.caseCount, 2);
      expect(g.closingCaseId, s.firstCase);
      expect((g.memberCount, g.paidCount, g.pendingCount, g.dueCount), (2, 1, 0, 1));
      expect(g.toCollect, 100);

      final dues = await s.agent.fetchGroupDues(s.yojnaId, _Scenario.group);
      expect(dues.map((d) => d.memberId), [s.ids['M2'], s.ids['M1']]);

      // The office sees everyone: M1, M2 and M3.
      final all = s.base.allDues().where((d) => d.yojnaId == s.yojnaId).toList();
      expect(all.map((d) => d.memberId).toSet(), {s.ids['M1'], s.ids['M2'], s.ids['M3']});
      expect(all.fold<double>(0, (sum, d) => sum + d.due), 200);
    });

    test('the office dues list sums each member across closings', () async {
      final s = await _Scenario.build();
      final q = DuesQuery(yojnaId: s.yojnaId);

      // Same order and totals as office_member_dues in dues_test.sql, before
      // the agent collects from M2.
      final page = await s.base.fetchDuesPage(q, offset: 0, limit: 20);
      expect(
        page.items.map((r) => r.name),
        ['Dues M2', 'Dues M3', 'Dues M1', 'Dues M4', 'Dues M5'],
      );
      final m1 = page.items.singleWhere((r) => r.name == 'Dues M1');
      expect((m1.closingsOwed, m1.due, m1.contributed), (0, 0, 100));
      expect(m1.lastContribution, isNotNull);
      final m2 = page.items.first;
      expect((m2.closingsOwed, m2.due, m2.contributed), (1, 100, 0));

      final totals = await s.base.fetchDuesTotals(q);
      expect(
        (totals.memberCount, totals.owingCount, totals.due, totals.contributed),
        (5, 2, 200, 100),
      );

      Future<int> count(DuesQuery q) async =>
          (await s.base.fetchDuesPage(q, offset: 0, limit: 20)).total;
      expect(
        await count(DuesQuery(yojnaId: s.yojnaId, standing: DuesStanding.owing)),
        2,
      );
      expect(
        await count(DuesQuery(yojnaId: s.yojnaId, standing: DuesStanding.clear)),
        3,
      );
      final other = s.base.membersView
          .singleWhere((m) => m.id == s.ids['M3'])
          .agentId;
      expect(await count(DuesQuery(yojnaId: s.yojnaId, agentId: other)), 1);

      // The agent's collection waits; M2 still owes until it is approved.
      await s.agent.recordPayment(s.contribution('M2'));
      final after = await s.base.fetchDuesTotals(q);
      expect((after.owingCount, after.due, after.pending), (2, 200, 100));
    });

    test('collecting links the receipt and blocks a second collection', () async {
      final s = await _Scenario.build();

      await s.agent.recordPayment(s.contribution('M2'));
      final g = await s.myGroup();
      expect((g.paidCount, g.pendingCount, g.dueCount, g.toCollect), (1, 1, 0, 0.0));

      final receipts = await s.agent.fetchMyPayments(offset: 0, limit: 5);
      expect(receipts.items.first.closingGroup, _Scenario.group);

      await expectLater(
        s.agent.recordPayment(s.contribution('M2')),
        _throwsMessage('already collected'),
      );
      await expectLater(
        s.agent.recordPayment(s.contribution('M1', closing: s.ids['c2'])),
        _throwsMessage('already collected'),
      );
      await expectLater(
        s.agent.recordPayment(s.contribution('M4')),
        _throwsMessage('does not owe'),
      );
      await expectLater(
        s.agent.fetchMemberDues(s.ids['M3']!),
        _throwsMessage('Member not found'),
      );

      // Approval settles it; cancelling makes it due again.
      final pending = (await s.base.fetchPendingPayments()).items
          .singleWhere((p) => p.memberId == s.ids['M2']);
      await s.base.approvePayment(pending.id);
      expect((await s.base.fetchMemberDues(s.ids['M2']!)).single.due, 0);
      await s.base.cancelPayment(pending.id, 'Test');
      expect((await s.base.fetchMemberDues(s.ids['M2']!)).single.due, 100);
    });

    test('a death report becomes a closing when the office approves it', () async {
      final s = await _Scenario.build();
      ClosingRequest report(String member, String url) => ClosingRequest(
            id: '',
            memberId: s.ids[member]!,
            dateOfDeath: DateTime.now().subtract(const Duration(days: 3)),
            nomineeName: 'Nominee One',
            certificateUrl: url,
          );
      const url = 'https://res.cloudinary.com/demo/image/upload/m1.jpg';

      await expectLater(
        s.agent.reportDeath(report('M1', 'https://example.com/m1.jpg')),
        _throwsMessage('Upload the death certificate'),
      );
      await expectLater(
        s.agent.reportDeath(report('M3', url)),
        _throwsMessage('Member not found'),
      );
      await s.agent.reportDeath(report('M1', url));
      await expectLater(
        s.agent.reportDeath(report('M1', url)),
        _throwsMessage('already waiting'),
      );

      final queued = (await s.base.fetchPendingClosingRequests()).single;
      expect(queued.memberName, 'Dues M1');
      await expectLater(
        s.base.approveClosingRequest(queued.id, closingGroup: ' '),
        _throwsMessage('closing group'),
      );
      final caseId =
          await s.base.approveClosingRequest(queued.id, closingGroup: 'T-2');

      final created =
          (await s.base.fetchClosingCases()).singleWhere((c) => c.id == caseId);
      expect(created.claimAmount, 50000);
      expect(created.nomineeName, 'Nominee One');
      expect(
        (await s.base.fetchMembersByIds([s.ids['M1']!])).single.status,
        MemberStatus.closed,
      );
      expect((await s.agent.fetchMyDeathReports()).single.status,
          RequestStatus.approved);
      expect(await s.base.fetchPendingClosingRequests(), isEmpty);
    });

    test('the demo uploader accepts photos and PDFs up to 10 MB', () async {
      final uploader = FakeCertificateUploader();
      expect(
        await uploader.upload(Uint8List(10), 'certificate.pdf'),
        startsWith('https://res.cloudinary.com/'),
      );
      await expectLater(
        uploader.upload(Uint8List(10), 'notes.docx'),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        uploader.upload(Uint8List(CertificateUploader.maxBytes + 1), 'big.jpg'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('screens', () {
    Future<(ProviderContainer, _Scenario)> pumpAgent(
      WidgetTester tester,
      Size size,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final s = (await tester.runAsync(_Scenario.build))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(s.base),
            authControllerProvider.overrideWith(() => _AgentAuth(s.me.id)),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RudranshAdminApp)),
      );
      return (container, s);
    }

    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets('agent dues pages lay out at ${size.width.toInt()} px',
          (tester) async {
        final (container, s) = await pumpAgent(tester, size);

        container.read(routerProvider).go(AppRoutes.agentDues);
        await tester.pumpAndSettle();
        expect(find.text(_Scenario.group), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text(_Scenario.group).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_Scenario.group).first);
        await tester.pumpAndSettle();
        expect(find.text('Dues M2'), findsOneWidget);
        expect(find.text('Dues M1'), findsNothing, reason: 'paid is filtered out');
        expect(find.widgetWithText(OutlinedButton, S.sendReminder), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('collecting from the dues list preselects the closing',
        (tester) async {
      final (container, s) = await pumpAgent(tester, const Size(390, 844));
      container.read(routerProvider).go(
            Uri(
              path: AppRoutes.agentDuesGroup,
              queryParameters: {'yojna': s.yojnaId, 'group': _Scenario.group},
            ).toString(),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
      await tester.pumpAndSettle();
      expect(find.text(S.forClosing), findsOneWidget);
      expect(find.textContaining('${_Scenario.group} · '), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    Future<(ProviderContainer, _Scenario)> pumpOffice(
      WidgetTester tester,
      Size size,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final s = (await tester.runAsync(_Scenario.build))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(s.base),
            signedInAs(UserRole.owner),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RudranshAdminApp)),
      );
      container.read(selectedYojnaIdProvider.notifier).select(s.yojnaId);
      container.read(routerProvider).go(AppRoutes.dues);
      await tester.pumpAndSettle();
      return (container, s);
    }

    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets('the office dues page lays out at ${size.width.toInt()} px',
          (tester) async {
        await pumpOffice(tester, size);

        expect(find.text('Members owing'), findsOneWidget);
        expect(find.text('₹200'), findsWidgets, reason: 'total due tile');
        for (final name in ['Dues M1', 'Dues M2', 'Dues M3', 'Dues M4', 'Dues M5']) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.text('Dues D1'), findsNothing, reason: 'closed members');
        expect(tester.takeException(), isNull);

        // The breakdown: the closing and the past contributions.
        await tester.ensureVisible(find.text('Dues M1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dues M1'));
        await tester.pumpAndSettle();
        expect(find.text('Past contributions'), findsOneWidget);
        expect(find.text(_Scenario.group), findsOneWidget);
        expect(find.text(DueState.paid.label), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Pay on the dues page preselects the oldest closing owed',
        (tester) async {
      await pumpOffice(tester, const Size(1440, 900));

      // Most owed first, so the first Pay is M2's.
      await tester.tap(find.widgetWithText(FilledButton, 'Pay').first);
      await tester.pumpAndSettle();
      expect(find.text(S.addPayment), findsWidgets);
      expect(find.text('Dues M2'), findsWidgets);
      expect(find.textContaining('${_Scenario.group} · '), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, '100'),
        findsOneWidget,
        reason: 'the amount left on the closing',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the approvals page lists a death report', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);

      final s = (await tester.runAsync(_Scenario.build))!;
      await tester.runAsync(
        () => s.agent.reportDeath(
          ClosingRequest(
            id: '',
            memberId: s.ids['M2']!,
            dateOfDeath: DateTime.now(),
            certificateUrl: 'https://res.cloudinary.com/demo/image/upload/m2.jpg',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(s.base),
            signedInAs(UserRole.owner),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(RudranshAdminApp)))
          .read(routerProvider)
          .go(AppRoutes.approvals);
      await tester.pumpAndSettle();

      expect(find.text('${S.deathReports} (1)'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, S.createClosing));
      await tester.pumpAndSettle();
      expect(find.text('${S.closingGroup} *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
