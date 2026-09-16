import 'package:flutter/foundation.dart';

import 'member.dart';
import 'payment.dart';

/// One page of a server-side list.
@immutable
class PageResult<T> {
  const PageResult({required this.items, required this.total});

  static PageResult<T> empty<T>() => PageResult<T>(items: const [], total: 0);

  final List<T> items;

  /// Rows matching the query across all pages.
  final int total;
}

/// Filters for the members list. Equality makes it usable as a cache key.
@immutable
class MemberQuery {
  const MemberQuery({
    this.yojnaId,
    this.text = '',
    this.status,
    this.agentId,
    this.district,
  });

  final String? yojnaId;

  /// Matches name, reg no, father/husband, phones, village, district, waris.
  final String text;
  final MemberStatus? status;
  final String? agentId;
  final String? district;

  @override
  bool operator ==(Object other) =>
      other is MemberQuery &&
      other.yojnaId == yojnaId &&
      other.text == text &&
      other.status == status &&
      other.agentId == agentId &&
      other.district == district;

  @override
  int get hashCode => Object.hash(yojnaId, text, status, agentId, district);
}

/// Filters for the payments ledger.
@immutable
class PaymentQuery {
  const PaymentQuery({
    this.yojnaId,
    this.memberId,
    this.text = '',
    this.mode,
    this.status,
    this.kind,
    this.from,
    this.to,
  });

  final String? yojnaId;
  final String? memberId;

  /// Matches receipt no, reference, and the member's name / reg no / phone.
  final String text;
  final PaymentMode? mode;
  final PaymentStatus? status;
  final PaymentKind? kind;

  /// Inclusive date range (dates only; time of day is ignored).
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is PaymentQuery &&
      other.yojnaId == yojnaId &&
      other.memberId == memberId &&
      other.text == text &&
      other.mode == mode &&
      other.status == status &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode =>
      Object.hash(yojnaId, memberId, text, mode, status, kind, from, to);
}

/// The few member fields a payment row needs to show who paid.
@immutable
class MemberRef {
  const MemberRef({
    required this.id,
    required this.name,
    required this.regNo,
    this.primaryPhone = '',
  });

  factory MemberRef.of(Member m) => MemberRef(
        id: m.id,
        name: m.name,
        regNo: m.regNo,
        primaryPhone: m.primaryPhone,
      );

  final String id;
  final String name;
  final String regNo;
  final String primaryPhone;
}

/// A page of payments plus the members they belong to.
@immutable
class PaymentPage extends PageResult<Payment> {
  const PaymentPage({
    required super.items,
    required super.total,
    this.members = const {},
  });

  static const empty = PaymentPage(items: [], total: 0);

  final Map<String, MemberRef> members;
}

/// Totals for the payment page summary strip.
@immutable
class PaymentTotals {
  const PaymentTotals({
    required this.count,
    required this.paid,
    required this.pending,
    required this.failed,
  });

  static const empty = PaymentTotals(count: 0, paid: 0, pending: 0, failed: 0);

  final int count;
  final double paid;
  final double pending;
  final double failed;

  double get total => paid + pending + failed;
}

@immutable
class DashboardStats {
  const DashboardStats({
    required this.totalMembers,
    required this.activeMembers,
    required this.inactiveMembers,
    required this.closedMembers,
    required this.totalAgents,
    required this.activeAgents,
    required this.monthCollection,
    required this.previousMonthCollection,
    required this.pendingClaims,
  });

  static const empty = DashboardStats(
    totalMembers: 0,
    activeMembers: 0,
    inactiveMembers: 0,
    closedMembers: 0,
    totalAgents: 0,
    activeAgents: 0,
    monthCollection: 0,
    previousMonthCollection: 0,
    pendingClaims: 0,
  );

  final int totalMembers;
  final int activeMembers;
  final int inactiveMembers;
  final int closedMembers;
  final int totalAgents;
  final int activeAgents;
  final double monthCollection;
  final double previousMonthCollection;
  final double pendingClaims;

  /// Month-over-month change, `null` when there is no baseline.
  double? get collectionDelta {
    if (previousMonthCollection <= 0) return null;
    return (monthCollection - previousMonthCollection) /
        previousMonthCollection *
        100;
  }
}
