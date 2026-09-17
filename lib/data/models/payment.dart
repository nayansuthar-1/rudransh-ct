import 'package:flutter/foundation.dart';

enum PaymentMode {
  cash('Cash'),
  upi('UPI'),
  bank('Bank Transfer'),
  cheque('Cheque');

  const PaymentMode(this.label);
  final String label;

  static PaymentMode fromName(String? value) => PaymentMode.values
      .firstWhere((m) => m.name == value, orElse: () => PaymentMode.cash);
}

enum PaymentStatus {
  paid('Paid'),
  pending('Pending'),
  failed('Failed');

  const PaymentStatus(this.label);
  final String label;

  static PaymentStatus fromName(String? value) => PaymentStatus.values
      .firstWhere((s) => s.name == value, orElse: () => PaymentStatus.paid);
}

/// Category of money movement recorded against a member.
enum PaymentKind {
  registration('Registration'),
  contribution('Contribution'),
  closingPayout('Closing Payout');

  const PaymentKind(this.label);
  final String label;

  static PaymentKind fromName(String? value) => PaymentKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => PaymentKind.contribution,
      );
}

/// Who recorded a payment (IMPLEMENTATION_PLAN §11).
enum PaymentSource {
  admin('Office'),
  agent('Agent'),
  member('Member');

  const PaymentSource(this.label);
  final String label;

  static PaymentSource fromName(String? value) => PaymentSource.values
      .firstWhere((s) => s.name == value, orElse: () => PaymentSource.admin);
}

@immutable
class Payment {
  const Payment({
    required this.id,
    required this.receiptNo,
    required this.memberId,
    required this.yojnaId,
    required this.amount,
    required this.date,
    this.mode = PaymentMode.cash,
    this.status = PaymentStatus.paid,
    this.kind = PaymentKind.contribution,
    this.agentId,
    this.reference = '',
    this.note = '',
    this.source = PaymentSource.admin,
    this.rejectReason = '',
    this.cancelledAt,
    this.cancelReason = '',
    this.cancelRequestedAt,
    this.cancelRequestReason = '',
  });

  final String id;
  final String receiptNo;
  final String memberId;
  final String yojnaId;
  final double amount;
  final DateTime date;
  final PaymentMode mode;
  final PaymentStatus status;
  final PaymentKind kind;

  /// Agent who collected the payment, when applicable.
  final String? agentId;

  /// UTR / cheque number / UPI reference.
  final String reference;
  final String note;

  // Set by the database; the admin forms never write them.
  final PaymentSource source;

  /// Why an admin rejected an agent's payment.
  final String rejectReason;

  /// Cancelled receipts stay on record but leave every total.
  final DateTime? cancelledAt;
  final String cancelReason;

  /// An agent asked for this receipt to be cancelled.
  final DateTime? cancelRequestedAt;
  final String cancelRequestReason;

  bool get isCancelled => cancelledAt != null;
  bool get hasOpenCancelRequest => cancelRequestedAt != null && !isCancelled;

  Payment copyWith({
    String? id,
    String? receiptNo,
    String? memberId,
    String? yojnaId,
    double? amount,
    DateTime? date,
    PaymentMode? mode,
    PaymentStatus? status,
    PaymentKind? kind,
    String? agentId,
    bool clearAgent = false,
    String? reference,
    String? note,
    String? rejectReason,
    DateTime? cancelledAt,
    String? cancelReason,
    DateTime? cancelRequestedAt,
    String? cancelRequestReason,
    bool clearCancelRequest = false,
  }) {
    return Payment(
      id: id ?? this.id,
      receiptNo: receiptNo ?? this.receiptNo,
      memberId: memberId ?? this.memberId,
      yojnaId: yojnaId ?? this.yojnaId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      reference: reference ?? this.reference,
      note: note ?? this.note,
      source: source,
      rejectReason: rejectReason ?? this.rejectReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelRequestedAt: clearCancelRequest
          ? null
          : (cancelRequestedAt ?? this.cancelRequestedAt),
      cancelRequestReason: clearCancelRequest
          ? ''
          : (cancelRequestReason ?? this.cancelRequestReason),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'receiptNo': receiptNo,
        'memberId': memberId,
        'yojnaId': yojnaId,
        'amount': amount,
        'date': date.toIso8601String(),
        'mode': mode.name,
        'status': status.name,
        'kind': kind.name,
        'agentId': agentId,
        'reference': reference,
        'note': note,
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        receiptNo: map['receiptNo'] as String? ?? '',
        memberId: map['memberId'] as String,
        yojnaId: map['yojnaId'] as String,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        mode: PaymentMode.fromName(map['mode'] as String?),
        status: PaymentStatus.fromName(map['status'] as String?),
        kind: PaymentKind.fromName(map['kind'] as String?),
        agentId: map['agentId'] as String?,
        reference: map['reference'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Payment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
