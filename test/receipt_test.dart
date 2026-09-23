import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/core/config/trust_info.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/features/receipt/receipt_data.dart';
import 'package:rudransh_ct/features/receipt/receipt_html.dart';

void main() {
  group('receipt data', () {
    test('converts amounts to Hindi words correctly', () {
      final r1 = ReceiptData(
        receiptNo: 'RCP-1001',
        date: DateTime(2026, 9, 23),
        amount: 300,
        memberName: 'Kalpesh Kumar',
      );
      expect(r1.amountInWordsHindi, 'तीन सौ रुपये मात्र');

      final r2 = ReceiptData(
        receiptNo: 'RCP-1002',
        date: DateTime(2026, 9, 23),
        amount: 1500,
        memberName: 'Nayan',
      );
      expect(r2.amountInWordsHindi, 'एक हज़ार पाँच सौ रुपये मात्र');
    });

    test('builds from Payment model accurately', () {
      final p = Payment(
        id: 'p1',
        receiptNo: 'RCP-1005',
        memberId: 'm1',
        yojnaId: 'y1',
        amount: 300,
        date: DateTime(2026, 5, 15),
        mode: PaymentMode.cash,
        kind: PaymentKind.contribution,
        closingGroup: 'Group-14',
      );

      final data = ReceiptData.fromPayment(
        payment: p,
        memberName: 'Kalpesh Kumar',
        yojnaName: 'Parivar Sahyog Yojna',
        agentName: 'Prema Ji',
      );

      expect(data.receiptNo, 'RCP-1005');
      expect(data.amount, 300);
      expect(data.memberName, 'Kalpesh Kumar');
      expect(data.closingGroup, 'Group-14');
      expect(data.paymentKind, contains('Group-14'));
      expect(data.agentName, 'Prema Ji');
    });
  });

  group('receipt html', () {
    final d = ReceiptData(
      receiptNo: 'RCP-1001',
      date: DateTime(2026, 5, 15),
      amount: 300,
      memberName: 'Kalpesh Kumar',
      regNo: 'R707604',
      fatherOrHusbandName: 'Bhagavan Ji',
      phone: '9586340736',
      yojnaName: 'मामेरा सहयोग योजना',
      closingGroup: 'Group-1',
      paymentKind: 'सहयोग राशि',
      paymentMode: 'नकद (Cash)',
      agentName: 'Prema Ji',
    );

    final html = buildReceiptHtml(d, baseUrl: 'https://trust.test/');

    test('contains all essential receipt fields', () {
      expect(html, contains('RCP-1001'));
      expect(html, contains('Kalpesh Kumar'));
      expect(html, contains('R707604'));
      expect(html, contains('Bhagavan Ji'));
      expect(html, contains('9586340736'));
      expect(html, contains('मामेरा सहयोग योजना'));
      expect(html, contains('तीन सौ रुपये मात्र'));
      expect(html, contains(TrustInfo.nameHindi));
      expect(html, contains(TrustInfo.registrationNo));
      expect(html, contains('सहयोग रसीद'));
      expect(html, contains('window.print()'));
    });
  });
}
