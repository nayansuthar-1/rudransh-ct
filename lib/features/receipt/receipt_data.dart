import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';

/// Data needed to print an official charitable trust donation / contribution receipt.
@immutable
class ReceiptData {
  const ReceiptData({
    required this.receiptNo,
    required this.date,
    required this.amount,
    required this.memberName,
    this.regNo = '',
    this.fatherOrHusbandName = '',
    this.phone = '',
    this.address = '',
    this.yojnaName = '',
    this.closingGroup = '',
    this.paymentKind = '',
    this.paymentMode = '',
    this.reference = '',
    this.agentName = '',
    this.note = '',
    this.isCancelled = false,
  });

  final String receiptNo;
  final DateTime date;
  final double amount;
  final String memberName;
  final String regNo;
  final String fatherOrHusbandName;
  final String phone;
  final String address;
  final String yojnaName;
  final String closingGroup;
  final String paymentKind;
  final String paymentMode;
  final String reference;
  final String agentName;
  final String note;
  final bool isCancelled;

  factory ReceiptData.fromPayment({
    required Payment payment,
    Member? member,
    MemberRef? memberRef,
    Yojna? yojna,
    Agent? agent,
    String memberName = '',
    String agentName = '',
    String yojnaName = '',
  }) {
    final kindLabel = switch (payment.kind) {
      PaymentKind.registration => 'पंजीकरण शुल्क',
      PaymentKind.contribution => payment.closingGroup.isNotEmpty
          ? 'सहयोग राशि (${payment.closingGroup})'
          : 'सहयोग राशि',
      PaymentKind.closingPayout => 'क्लेम भुगतान',
    };

    final modeLabel = switch (payment.mode) {
      PaymentMode.cash => 'नकद (Cash)',
      PaymentMode.upi => 'यूपीआई (UPI)',
      PaymentMode.bank => 'बैंक ट्रांसफर (Bank)',
      PaymentMode.cheque => 'चेक (Cheque)',
    };

    final effectiveMemberName = member?.name ??
        memberRef?.name ??
        (memberName.isNotEmpty ? memberName : '');
    final effectiveRegNo =
        member?.regNo ?? memberRef?.regNo ?? '';
    final effectivePhone =
        member?.primaryPhone ?? memberRef?.primaryPhone ?? '';
    final effectiveYojnaName =
        yojna?.name ?? yojnaName;
    final effectiveAgentName =
        agentName.isNotEmpty ? agentName : (agent?.name ?? '');

    return ReceiptData(
      receiptNo: payment.receiptNo,
      date: payment.date,
      amount: payment.amount,
      memberName: effectiveMemberName,
      regNo: effectiveRegNo,
      fatherOrHusbandName: member?.fatherOrHusbandName ?? '',
      phone: effectivePhone,
      address: member?.address ?? '',
      yojnaName: effectiveYojnaName,
      closingGroup: payment.closingGroup,
      paymentKind: kindLabel,
      paymentMode: modeLabel,
      reference: payment.reference,
      agentName: effectiveAgentName,
      note: payment.note,
      isCancelled: payment.isCancelled,
    );
  }

  /// Converts an integer amount to Hindi words up to 99,99,999.
  String get amountInWordsHindi {
    final n = amount.round();
    if (n <= 0) return 'शून्य रुपये मात्र';

    final ones = [
      '', 'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ',
      'दस', 'ग्यारह', 'बारह', 'तेरह', 'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह', 'उन्नीस',
      'बीस', 'इक्कीस', 'बाईस', 'तेईस', 'चौबीस', 'पच्चीस', 'छब्बीस', 'सत्ताईस', 'अट्ठाइस', 'उनतीस',
      'तीस', 'इकतीस', 'बत्तीस', 'तैंतीस', 'चौंतीस', 'पैंतीस', 'छत्तीस', 'सैंतीस', 'अड़तीस', 'उनतालीस',
      'चालीस', 'इकतालीस', 'बयालीस', 'तैंतालीस', 'चवालीस', 'पैंतालीस', 'छियालीस', 'सैंतालीस', 'अड़तालीस', 'उनचास',
      'पचास', 'इक्यावन', 'बावन', 'तिरेपन', 'चौवन', 'पचपन', 'छप्पन', 'सत्तावन', 'अट्ठावन', 'उनसठ',
      'साठ', 'इकसठ', 'बासठ', 'तिरसठ', 'चौंसठ', 'पैंसठ', 'छियासठ', 'सड़सठ', 'अड़सठ', 'उनहत्तर',
      'सत्तर', 'इकहत्तर', 'बहत्तर', 'तिहत्तर', 'चौहत्तर', 'पचहत्तर', 'छिहत्तर', 'सतहत्तर', 'अठहत्तर', 'उन्नासी',
      'अस्सी', 'इक्यासी', 'बयासी', 'तिरासी', 'चौरासी', 'पचासी', 'छियासी', 'सत्तासी', 'अट्ठासी', 'नवासी',
      'नब्बे', 'इक्यानवे', 'बानवे', 'तिरानवे', 'चौरानवे', 'पंचानवे', 'छियानवे', 'सत्तानवे', 'अट्ठानवे', 'निन्यानवे'
    ];

    String convertLessThousand(int num) {
      var res = '';
      if (num >= 100) {
        res += '${ones[num ~/ 100]} सौ ';
        num %= 100;
      }
      if (num > 0) {
        res += '${ones[num]} ';
      }
      return res.trim();
    }

    var num = n;
    var words = '';

    if (num >= 10000000) {
      final crore = num ~/ 10000000;
      words += '${convertLessThousand(crore)} करोड़ ';
      num %= 10000000;
    }
    if (num >= 100000) {
      final lakh = num ~/ 100000;
      words += '${convertLessThousand(lakh)} लाख ';
      num %= 100000;
    }
    if (num >= 1000) {
      final thousand = num ~/ 1000;
      words += '${convertLessThousand(thousand)} हज़ार ';
      num %= 1000;
    }
    if (num > 0) {
      words += convertLessThousand(num);
    }

    return '${words.trim()} रुपये मात्र';
  }
}
