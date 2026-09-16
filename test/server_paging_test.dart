import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'package:rudransh_ct/state/selectors.dart';

InMemoryTrustRepository _repo() =>
    InMemoryTrustRepository(latency: Duration.zero);

void main() {
  group('paged repository queries', () {
    test('member pages are disjoint and add up to the total', () async {
      final repo = _repo();
      final all = await repo.fetchMembers();

      final first = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: 0,
        limit: 20,
      );
      final second = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: 20,
        limit: 20,
      );

      expect(first.total, all.length);
      expect(first.items, hasLength(20));
      expect(
        first.items.map((m) => m.id).toSet().intersection(
              second.items.map((m) => m.id).toSet(),
            ),
        isEmpty,
      );

      final past = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: all.length + 40,
        limit: 20,
      );
      expect(past.items, isEmpty);
      expect(past.total, all.length);
    });

    test('member query filters by scheme, status and text', () async {
      final repo = _repo();
      final all = await repo.fetchMembers();
      final target = all.firstWhere((m) => m.status == MemberStatus.active);

      final page = await repo.fetchMembersPage(
        MemberQuery(
          yojnaId: target.yojnaId,
          status: MemberStatus.active,
          text: target.regNo,
        ),
        offset: 0,
        limit: 20,
      );
      expect(page.items.map((m) => m.id), contains(target.id));
      expect(page.items.every((m) => m.yojnaId == target.yojnaId), isTrue);
    });

    test('payment pages carry their members and totals match rows', () async {
      final repo = _repo();
      final payments = await repo.fetchPayments();

      final page = await repo.fetchPaymentsPage(
        const PaymentQuery(),
        offset: 0,
        limit: 10,
      );
      expect(page.total, payments.length);
      for (final p in page.items) {
        expect(page.members[p.memberId], isNotNull);
      }

      final totals = await repo.fetchPaymentTotals(const PaymentQuery());
      final paid = payments
          .where((p) => p.status == PaymentStatus.paid)
          .fold<double>(0, (sum, p) => sum + p.amount);
      expect(totals.count, payments.length);
      expect(totals.paid, closeTo(paid, 0.001));
    });

    test('payment search matches the member name', () async {
      final repo = _repo();
      final payment = (await repo.fetchPayments()).first;
      final member = (await repo.fetchMembersByIds([payment.memberId])).single;

      final page = await repo.fetchPaymentsPage(
        PaymentQuery(text: member.name),
        offset: 0,
        limit: 100,
      );
      expect(page.items.map((p) => p.id), contains(payment.id));
    });

    test('member search can skip closed members', () async {
      final repo = _repo();
      final closed =
          (await repo.fetchMembers()).firstWhere((m) => m.isClosed);

      final found = await repo.searchMembers(closed.regNo, excludeClosed: true);
      expect(found.map((m) => m.id), isNot(contains(closed.id)));
    });
  });

  group('providers', () {
    test('saving a payment refreshes the totals', () async {
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(_repo())],
      );
      addTearDown(container.dispose);
      // Keep the provider alive between reads.
      container.listen(paymentTotalsProvider, (_, _) {});
      // Pin the scope; otherwise it switches to the first scheme once loaded.
      container.read(selectedYojnaIdProvider.notifier).select(null);

      final before = await container.read(paymentTotalsProvider.future);
      final member = (await container
              .read(repositoryProvider)
              .fetchMembersPage(const MemberQuery(), offset: 0, limit: 1))
          .items
          .single;

      await container.read(paymentActionsProvider).add(
            Payment(
              id: '',
              receiptNo: 'RCP-TEST',
              memberId: member.id,
              yojnaId: member.yojnaId,
              amount: 123,
              date: DateTime.now(),
            ),
          );

      final after = await container.read(paymentTotalsProvider.future);
      expect(after.count, before.count + 1);
      expect(after.paid, closeTo(before.paid + 123, 0.001));
    });

    test('changing a filter resets the members page', () async {
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(_repo())],
      );
      addTearDown(container.dispose);
      container.listen(memberPageProvider, (_, _) {});

      container.read(memberPageProvider.notifier).set(3);
      expect(container.read(memberPageProvider), 3);

      container
          .read(memberFilterProvider.notifier)
          .setStatus(MemberStatus.closed);
      expect(container.read(memberPageProvider), 0);
    });
  });

  testWidgets('members table pages through the server', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(_repo())],
        child: const RudranshAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    // All schemes, so the seed data spans several pages.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RudranshAdminApp)),
    );
    container.read(selectedYojnaIdProvider.notifier).select(null);

    await tester.tap(find.text(S.members).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('1–$listPageSize of'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('${listPageSize + 1}–${listPageSize * 2} of'),
      findsOneWidget,
    );
    expect(container.read(memberPageProvider), 1);
  });
}
