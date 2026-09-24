import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/core/l10n/member_text.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:rudransh_ct/state/providers.dart';

import 'support/seed_data.dart';

/// Mirrors the rules of `record_online_payment` and `online_payment_due`
/// (migration 20260927000300), in memory.
void main() {
  late InMemoryTrustRepository repo;
  late MemberDue due;

  setUp(() async {
    repo = seededRepository(latency: Duration.zero);
    // A member who owes for a closing and has nothing waiting for approval.
    final owing = repo
        .allDues()
        .firstWhere((d) => d.due > 0 && d.pending == 0);
    repo.portalMemberId = owing.memberId;
    due = owing;
  });

  test('the order is for exactly what is owed', () async {
    final order = await repo.startOnlinePayment(due.closingCaseId);
    expect(order.amountPaise, (due.due * 100).round());
    expect(order.orderId, isNotEmpty);
  });

  test('a confirmed payment is a Paid online receipt and clears the due',
      () async {
    final order = await repo.startOnlinePayment(due.closingCaseId);
    final receipt = await repo.confirmOnlinePayment(
      orderId: order.orderId,
      paymentId: 'pay_1',
      signature: 'sig',
    );
    expect(receipt, isNotEmpty);

    final p = repo.paymentsView.firstWhere((p) => p.receiptNo == receipt);
    expect(p.mode, PaymentMode.online);
    expect(p.status, PaymentStatus.paid);
    expect(p.source, PaymentSource.member);
    expect(p.closingCaseId, due.closingCaseId);
    expect(p.amount, due.due);

    final after = repo.allDues().firstWhere(
          (d) =>
              d.memberId == due.memberId &&
              d.closingCaseId == due.closingCaseId,
        );
    expect(after.due, 0);
  });

  test('an order is recorded once', () async {
    final order = await repo.startOnlinePayment(due.closingCaseId);
    await repo.confirmOnlinePayment(
      orderId: order.orderId,
      paymentId: 'pay_1',
      signature: 'sig',
    );
    expect(
      () => repo.confirmOnlinePayment(
        orderId: order.orderId,
        paymentId: 'pay_1',
        signature: 'sig',
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('nothing owed means no order', () async {
    final order = await repo.startOnlinePayment(due.closingCaseId);
    await repo.confirmOnlinePayment(
      orderId: order.orderId,
      paymentId: 'pay_1',
      signature: 'sig',
    );
    expect(
      () => repo.startOnlinePayment(due.closingCaseId),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('closing the checkout records nothing', () async {
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final before = repo.paymentsView.length;

    final receipt = await container
        .read(portalActionsProvider)
        .payOnline(due.closingCaseId, checkout: (_) async => null);

    expect(receipt, isNull);
    expect(repo.paymentsView, hasLength(before));
  });

  test('paying through the actions returns the receipt', () async {
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final receipt = await container.read(portalActionsProvider).payOnline(
          due.closingCaseId,
          checkout: (order) async => (
            orderId: order.orderId,
            paymentId: 'pay_2',
            signature: 'sig',
          ),
        );
    expect(receipt, isNotNull);
    expect(repo.paymentsView.any((p) => p.receiptNo == receipt), isTrue);
  });

  test('nobody records an online payment by hand', () {
    expect(PaymentMode.manual, isNot(contains(PaymentMode.online)));
  });

  test('the button and the confirmation read in Hindi', () {
    const hi = MemberText(MemberLang.hi);
    expect(hi.payOnline, 'ऑनलाइन भुगतान करें');
    expect(hi.paidOnline('RCP-1001'), contains('RCP-1001'));
  });
}
