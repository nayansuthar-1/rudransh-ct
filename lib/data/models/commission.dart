import 'package:flutter/foundation.dart';

import 'dues.dart' show RequestStatus;

/// Cash an agent handed to the office, waiting for an admin to confirm it
/// (IMPLEMENTATION_PLAN Phase 16).
///
/// A handover is declared for whole receipts rather than a typed amount, so the
/// office can check the total against the receipts it holds. Rejecting one
/// unlinks its receipts, and the money goes back to the agent's cash in hand.
@immutable
class CashHandover {
  const CashHandover({
    required this.id,
    required this.amount,
    required this.declaredAt,
    this.agentId = '',
    this.agentCode = '',
    this.agentName = '',
    this.note = '',
    this.status = RequestStatus.pending,
    this.decisionNote = '',
    this.confirmedAt,
    this.receiptCount = 0,
  });

  final String id;
  final String agentId;
  final String agentCode;
  final String agentName;
  final double amount;
  final String note;
  final RequestStatus status;

  /// Why the office did not confirm it.
  final String decisionNote;
  final DateTime declaredAt;

  /// Set only when the money was received.
  final DateTime? confirmedAt;
  final int receiptCount;

  static CashHandover fromRow(Map<String, dynamic> r) => CashHandover(
        id: r['id'] as String,
        agentId: (r['agent_id'] ?? '') as String,
        agentCode: (r['agent_code'] ?? '') as String,
        agentName: (r['agent_name'] ?? '') as String,
        amount: (r['amount'] as num).toDouble(),
        note: (r['note'] ?? '') as String,
        status: RequestStatus.fromName(r['status'] as String?),
        decisionNote: (r['decision_note'] ?? '') as String,
        declaredAt: DateTime.parse(r['declared_at'] as String).toLocal(),
        confirmedAt: r['confirmed_at'] == null
            ? null
            : DateTime.parse(r['confirmed_at'] as String).toLocal(),
        receiptCount: (r['receipt_count'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CashHandover && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// One agent's commission for one calendar month.
///
/// [collected] and [amount] are recalculated on every read, so a receipt
/// cancelled later moves them. [paidAmount] is what the owner actually paid,
/// kept as it was: a difference between the two is a correction to look at,
/// not something to hide.
@immutable
class CommissionMonth {
  const CommissionMonth({
    required this.month,
    required this.collected,
    required this.percent,
    required this.amount,
    this.agentId = '',
    this.agentCode = '',
    this.agentName = '',
    this.paidAt,
    this.paidAmount,
    this.reference = '',
  });

  /// The first of the month.
  final DateTime month;
  final String agentId;
  final String agentCode;
  final String agentName;

  /// Approved collections in the month, before the percentage.
  final double collected;
  final double percent;

  /// [collected] × [percent].
  final double amount;

  final DateTime? paidAt;

  /// What was paid, once it was.
  final double? paidAmount;
  final String reference;

  bool get isPaid => paidAt != null;

  /// True when what was paid no longer matches what is owed.
  bool get differs => isPaid && (paidAmount ?? 0) != amount;

  static CommissionMonth fromRow(Map<String, dynamic> r, {DateTime? month}) =>
      CommissionMonth(
        month: month ?? DateTime.parse(r['month'] as String),
        agentId: (r['agent_id'] ?? '') as String,
        agentCode: (r['agent_code'] ?? '') as String,
        agentName: (r['agent_name'] ?? '') as String,
        collected: (r['collected'] as num).toDouble(),
        percent: (r['percent'] as num).toDouble(),
        amount: (r['amount'] as num).toDouble(),
        paidAt: r['paid_at'] == null
            ? null
            : DateTime.parse(r['paid_at'] as String).toLocal(),
        paidAmount: (r['paid_amount'] as num?)?.toDouble(),
        reference: (r['reference'] ?? '') as String,
      );
}

/// A receipt making up an agent's cash in hand, for the declare form.
@immutable
class OpenCashReceipt {
  const OpenCashReceipt({
    required this.id,
    required this.receiptNo,
    required this.amount,
    required this.date,
    this.memberName = '',
    this.memberRegNo = '',
  });

  final String id;
  final String receiptNo;
  final String memberName;
  final String memberRegNo;
  final double amount;
  final DateTime date;

  static OpenCashReceipt fromRow(Map<String, dynamic> r) => OpenCashReceipt(
        id: r['id'] as String,
        receiptNo: (r['receipt_no'] ?? '') as String,
        memberName: (r['member_name'] ?? '') as String,
        memberRegNo: (r['member_reg_no'] ?? '') as String,
        amount: (r['amount'] as num).toDouble(),
        date: DateTime.parse(r['date'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OpenCashReceipt && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
