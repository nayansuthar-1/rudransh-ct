import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/lookup_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';

import 'support/seed_data.dart';

/// Mirrors `supabase/tests/member_portal_test.sql`: the same rules, in memory.
void main() {
  group('public lookup', () {
    late InMemoryTrustRepository repo;
    late InMemoryLookupRepository lookup;
    late Member member;

    setUp(() async {
      repo = seededRepository();
      lookup = InMemoryLookupRepository(
        () => repo.membersView,
        () => repo.yojnasView,
        repo.allDues,
        payments: () => repo.paymentsView,
        agents: () => repo.agentsView,
      );
      member = repo.membersView.firstWhere(
        (m) => m.status == MemberStatus.active && m.aadhaar.isNotEmpty,
      );
    });

    test('the member gets their own papers, without the Aadhaar', () async {
      final found = (await lookup.find(
        phone: member.primaryPhone,
        aadhaar4: member.aadhaar.substring(member.aadhaar.length - 4),
        turnstileToken: 'test',
      ))
          .single;
      expect(found.member, isNotNull);
      expect(found.member!.regNo, member.regNo);
      expect(found.member!.fatherOrHusbandName, member.fatherOrHusbandName);
      expect(found.member!.aadhaar, isEmpty);

      final approved = repo.paymentsView.where((p) =>
          p.memberId == member.id &&
          p.status == PaymentStatus.paid &&
          !p.isCancelled);
      expect(
        found.receipts.map((p) => p.receiptNo).toSet(),
        approved.map((p) => p.receiptNo).toSet(),
      );
      for (var i = 1; i < found.receipts.length; i++) {
        expect(
          found.receipts[i - 1].date.isBefore(found.receipts[i].date),
          isFalse,
          reason: 'newest first',
        );
      }
    });

    test('the server row carries receipts and certificate fields', () {
      final l = MemberLookup.fromRow({
        'reg_no': 'SSY-2026-0001',
        'name': 'Ramesh',
        'yojna_name': 'Sahyog',
        'status': 'active',
        'join_date': '2026-07-01',
        'contribution_amount': 200,
        'dues_count': 0,
        'dues_amount': 0,
        'details': {
          'certificate': {
            'father_or_husband_name': 'Farhan',
            'gotra': 'Keshav',
            'dob': '1960-01-01',
            'yojna_description': 'note',
            'yojna_start_date': '2026-07-01',
            'agent_name': 'Agent A',
          },
          'receipts': [
            {
              'receipt_no': 'R-0007',
              'date': '2026-09-01',
              'amount': 200,
              'kind': 'contribution',
              'mode': 'upi',
              'reference': 'UTR1',
              'closing_group': 'A-1',
            },
          ],
        },
      });
      expect(l.member!.gotra, 'Keshav');
      expect(l.member!.dob, DateTime(1960, 1, 1));
      expect(l.payoutNote, 'note');
      expect(l.agentName, 'Agent A');
      expect(l.receipts.single.receiptNo, 'R-0007');
      expect(l.receipts.single.mode, PaymentMode.upi);
      expect(l.receipts.single.closingGroup, 'A-1');
    });

    test('an older server without details still gives the summary', () {
      final l = MemberLookup.fromRow({
        'reg_no': 'X',
        'name': 'Y',
        'status': 'active',
        'join_date': '2026-07-01',
      });
      expect(l.member, isNull);
      expect(l.receipts, isEmpty);
    });

    String last4(Member m) => m.aadhaar.substring(m.aadhaar.length - 4);

    Future<List<MemberLookup>> find({String? phone, String? aadhaar4}) =>
        lookup.find(
          phone: phone ?? member.primaryPhone,
          aadhaar4: aadhaar4 ?? last4(member),
          turnstileToken: 'test',
        );

    test('the phone and last four Aadhaar digits find the member', () async {
      final found = await find();
      expect(found, hasLength(1));
      expect(found.single.name, member.name);
      expect(found.single.regNo, member.regNo);
    });

    test('the alternate phone works too', () async {
      final withAlt = member.copyWith(altPhone: '9400000091');
      final alt = InMemoryLookupRepository(
        () => [withAlt],
        () => repo.yojnasView,
        repo.allDues,
      );
      final found = await alt.find(
        phone: '9400000091',
        aadhaar4: last4(member),
        turnstileToken: 'test',
      );
      expect(found, hasLength(1));
    });

    test('a wrong Aadhaar finds nothing', () async {
      expect(await find(aadhaar4: '0000'), isEmpty);
    });

    test('a wrong phone finds nothing', () async {
      expect(await find(phone: '9999999999'), isEmpty);
    });

    test('a member with no Aadhaar on record is not found on the phone alone',
        () async {
      final noAadhaar = member.copyWith(aadhaar: '');
      final bare = InMemoryLookupRepository(
        () => [noAadhaar],
        () => repo.yojnasView,
        repo.allDues,
      );
      final found = await bare.find(
        phone: member.primaryPhone,
        aadhaar4: '1234',
        turnstileToken: 'test',
      );
      expect(found, isEmpty);
    });

    test('every membership under the phone comes back', () async {
      final second = member.copyWith(
        id: 'second',
        regNo: '${member.regNo}-2',
        joinDate: member.joinDate.add(const Duration(days: 30)),
      );
      final both = InMemoryLookupRepository(
        () => [second, member],
        () => repo.yojnasView,
        repo.allDues,
      );
      final found = await both.find(
        phone: member.primaryPhone,
        aadhaar4: last4(member),
        turnstileToken: 'test',
      );
      expect(found.map((m) => m.regNo), [member.regNo, second.regNo]);
    });

    test('both details are required', () async {
      expect(() => find(phone: '   '), throwsA(isA<RepositoryException>()));
      expect(() => find(aadhaar4: ''), throwsA(isA<RepositoryException>()));
    });

    test('five wrong tries lock that phone', () async {
      for (var i = 0; i < 5; i++) {
        expect(await find(aadhaar4: '0000'), isEmpty);
      }
      expect(
        () => find(),
        throwsA(isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          contains('Too many wrong tries'),
        )),
      );
    });

    test('the lock is per phone number', () async {
      for (var i = 0; i < 5; i++) {
        await find(aadhaar4: '0000');
      }
      final other = repo.membersView.firstWhere(
        (m) =>
            m.primaryPhone != member.primaryPhone &&
            m.status == MemberStatus.active &&
            m.aadhaar.isNotEmpty,
      );
      final found = await lookup.find(
        phone: other.primaryPhone,
        aadhaar4: last4(other),
        turnstileToken: 'test',
      );
      expect(found, isNotEmpty, reason: 'another phone is unaffected');
    });
  });

  group('the member portal', () {
    late InMemoryTrustRepository repo;

    setUp(() {
      repo = seededRepository();
      repo.portalMemberId = repo.membersView
          .firstWhere((m) => m.status == MemberStatus.active)
          .id;
    });

    test('reads its own membership', () async {
      final m = await repo.fetchMyMembership();
      expect(m.memberId, repo.portalMemberId);
      expect(m.regNo, isNotEmpty);
      expect(m.yojnaName, isNotEmpty);
    });

    test('paying by UPI leaves a pending receipt', () async {
      final before = (await repo.fetchMyPayments()).length;
      await repo.submitUpiPayment(amount: 100, reference: 'UTR123456789');

      final after = await repo.fetchMyPayments();
      expect(after, hasLength(before + 1));
      expect(after.first.status, PaymentStatus.pending);
      expect(after.first.mode, PaymentMode.upi);
      expect(after.first.source, PaymentSource.member);
    });

    test('the same UPI reference twice is refused', () async {
      await repo.submitUpiPayment(amount: 100, reference: 'UTR123456789');
      expect(
        () => repo.submitUpiPayment(amount: 100, reference: 'UTR123456789'),
        throwsA(isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          contains('already recorded'),
        )),
      );
    });

    test('a zero amount and a short reference are refused', () async {
      expect(
        () => repo.submitUpiPayment(amount: 0, reference: 'UTR123456789'),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.submitUpiPayment(amount: 100, reference: 'x'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('a correction records what it was and what it should be', () async {
      final before = await repo.fetchMyMembership();
      await repo.requestChange(ChangeField.village, 'New Village');

      final mine = await repo.fetchMyChangeRequests();
      expect(mine, hasLength(1));
      expect(mine.first.field, ChangeField.village);
      expect(mine.first.oldValue, before.village);
      expect(mine.first.newValue, 'New Village');
      expect(mine.first.status, RequestStatus.pending);
    });

    test('one pending correction per field', () async {
      await repo.requestChange(ChangeField.village, 'New Village');
      expect(
        () => repo.requestChange(ChangeField.village, 'Third Village'),
        throwsA(isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          contains('already waiting'),
        )),
      );
    });

    test('a blank value is refused', () async {
      expect(
        () => repo.requestChange(ChangeField.village, '   '),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('approving applies the change and notifies the member', () async {
      await repo.requestChange(ChangeField.village, 'New Village');
      final pending = await repo.fetchPendingChangeRequests();
      expect(pending, hasLength(1));

      await repo.approveChangeRequest(pending.first.id);

      expect((await repo.fetchMyMembership()).village, 'New Village');
      expect(await repo.fetchPendingChangeRequests(), isEmpty);
      expect((await repo.fetchMyChangeRequests()).first.status,
          RequestStatus.approved);
      expect(
        (await repo.fetchNotifications()).first.title,
        'Your correction was applied',
      );
    });

    test('rejecting needs a reason and changes nothing', () async {
      final before = (await repo.fetchMyMembership()).village;
      await repo.requestChange(ChangeField.village, 'New Village');
      final pending = await repo.fetchPendingChangeRequests();

      expect(
        () => repo.rejectChangeRequest(pending.first.id, '   '),
        throwsA(isA<RepositoryException>()),
      );

      await repo.rejectChangeRequest(pending.first.id, 'Ask your agent');
      expect((await repo.fetchMyMembership()).village, before);
      expect((await repo.fetchMyChangeRequests()).first.decisionNote,
          'Ask your agent');
    });

    test('deciding twice is refused', () async {
      await repo.requestChange(ChangeField.village, 'New Village');
      final pending = await repo.fetchPendingChangeRequests();
      await repo.approveChangeRequest(pending.first.id);
      expect(
        () => repo.approveChangeRequest(pending.first.id),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('screens', () {
    Future<(ProviderContainer, InMemoryTrustRepository)> pump(
      WidgetTester tester,
      Size size, {
      required UserRole role,
      bool signedIn = true,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final repo = seededRepository();
      repo.portalMemberId = repo.membersView
          .firstWhere((m) => m.status == MemberStatus.active)
          .id;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            authControllerProvider.overrideWith(
              () => signedIn ? _Auth(role) : _SignedOut(),
            ),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (
        ProviderScope.containerOf(
          tester.element(find.byType(RudranshAdminApp)),
        ),
        repo,
      );
    }

    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets('the member home lays out at ${size.width.toInt()} px',
          (tester) async {
        final (container, _) =
            await pump(tester, size, role: UserRole.member);
        container.read(routerProvider).go(AppRoutes.memberHome);
        await tester.pumpAndSettle();

        expect(find.text(S.myMembership), findsOneWidget);
        expect(find.text(S.myCorrections), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the dues page lays out at ${size.width.toInt()} px',
          (tester) async {
        final (container, _) =
            await pump(tester, size, role: UserRole.member);
        container.read(routerProvider).go(AppRoutes.memberDues);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a signed-out visitor reaches the public lookup',
        (tester) async {
      final (container, _) = await pump(
        tester,
        const Size(390, 844),
        role: UserRole.member,
        signedIn: false,
      );
      container.read(routerProvider).go(AppRoutes.lookup);
      await tester.pumpAndSettle();

      expect(find.text(S.lookupTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the lookup finds a member and shows their standing',
        (tester) async {
      final (container, repo) = await pump(
        tester,
        const Size(390, 844),
        role: UserRole.member,
        signedIn: false,
      );
      final member = repo.membersView.firstWhere(
        (m) => m.status == MemberStatus.active && m.aadhaar.isNotEmpty,
      );

      container.read(routerProvider).go(AppRoutes.lookup);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), member.primaryPhone);
      await tester.enterText(
        fields.at(1),
        member.aadhaar.substring(member.aadhaar.length - 4),
      );
      await tester.tap(find.widgetWithText(FilledButton, S.lookupSubmit));
      await tester.pumpAndSettle();

      expect(find.text(member.name), findsOneWidget);
      expect(find.text(S.printCertificate), findsOneWidget);
      expect(find.text('Receipts'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, S.lookupAgain), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrong phone says so without naming anyone', (tester) async {
      final (container, repo) = await pump(
        tester,
        const Size(390, 844),
        role: UserRole.member,
        signedIn: false,
      );
      final member = repo.membersView
          .firstWhere((m) => m.status == MemberStatus.active);

      container.read(routerProvider).go(AppRoutes.lookup);
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '9999999999');
      await tester.enterText(fields.at(1), '1234');
      await tester.tap(find.widgetWithText(FilledButton, S.lookupSubmit));
      await tester.pumpAndSettle();

      expect(find.text(S.lookupNotFound), findsOneWidget);
      expect(find.text(member.name), findsNothing);
    });

    testWidgets('an admin sees corrections in the approvals queue',
        (tester) async {
      final (container, repo) =
          await pump(tester, const Size(1440, 900), role: UserRole.owner);

      await tester.runAsync(
        () => repo.requestChange(ChangeField.village, 'New Village'),
      );
      container.read(dataRevisionProvider.notifier).bump();
      container.read(routerProvider).go(AppRoutes.approvals);
      await tester.pumpAndSettle();

      expect(find.text('${S.changeRequests} (1)'), findsOneWidget);
      expect(find.text('To: New Village'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, S.approve).last);
      await tester.pumpAndSettle();

      expect(
        (await tester.runAsync(repo.fetchMyMembership))!.village,
        'New Village',
      );
    });
  });
}

class _Auth extends AuthController {
  _Auth(this.role);

  final UserRole role;

  @override
  AuthState build() => AuthState(
        stage: AuthStage.signedIn,
        email: 'user@test.local',
        user: AppUser(
          id: 'user-1',
          name: 'Test User',
          email: 'user@test.local',
          role: role,
        ),
      );
}

class _SignedOut extends AuthController {
  @override
  AuthState build() => const AuthState();
}
