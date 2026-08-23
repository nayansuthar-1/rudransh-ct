import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'providers.dart';

// ---------------------------------------------------------------------------
// Member filtering
// ---------------------------------------------------------------------------

@immutable
class MemberFilter {
  const MemberFilter({
    this.query = '',
    this.status,
    this.agentId,
    this.district,
  });

  final String query;
  final MemberStatus? status;
  final String? agentId;
  final String? district;

  bool get isEmpty =>
      query.isEmpty && status == null && agentId == null && district == null;

  MemberFilter copyWith({
    String? query,
    MemberStatus? status,
    String? agentId,
    String? district,
    bool clearStatus = false,
    bool clearAgent = false,
    bool clearDistrict = false,
  }) {
    return MemberFilter(
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      district: clearDistrict ? null : (district ?? this.district),
    );
  }
}

class MemberFilterNotifier extends Notifier<MemberFilter> {
  @override
  MemberFilter build() => const MemberFilter();

  void setQuery(String value) => state = state.copyWith(query: value);
  void setStatus(MemberStatus? value) =>
      state = state.copyWith(status: value, clearStatus: value == null);
  void setAgent(String? value) =>
      state = state.copyWith(agentId: value, clearAgent: value == null);
  void setDistrict(String? value) =>
      state = state.copyWith(district: value, clearDistrict: value == null);
  void clear() => state = const MemberFilter();
}

final memberFilterProvider =
    NotifierProvider<MemberFilterNotifier, MemberFilter>(
  MemberFilterNotifier.new,
);

/// Members of the scheme selected in the top bar (all schemes when null).
final scopedMembersProvider = Provider<List<Member>>((ref) {
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final yojnaId = ref.watch(selectedYojnaIdProvider);
  if (yojnaId == null) return members;
  return members.where((m) => m.yojnaId == yojnaId).toList();
});

final filteredMembersProvider = Provider<List<Member>>((ref) {
  final members = ref.watch(scopedMembersProvider);
  final f = ref.watch(memberFilterProvider);
  final q = f.query.trim().toLowerCase();

  final result = members.where((m) {
    if (q.isNotEmpty && !m.searchIndex.contains(q)) return false;
    if (f.status != null && m.status != f.status) return false;
    if (f.agentId != null && m.agentId != f.agentId) return false;
    if (f.district != null && m.district != f.district) return false;
    return true;
  }).toList();

  result.sort((a, b) => b.joinDate.compareTo(a.joinDate));
  return result;
});

final memberDistrictsProvider = Provider<List<String>>((ref) {
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final set = members
      .map((m) => m.district)
      .where((d) => d.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return set;
});

// ---------------------------------------------------------------------------
// Agent filtering
// ---------------------------------------------------------------------------

class AgentQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final agentQueryProvider =
    NotifierProvider<AgentQueryNotifier, String>(AgentQueryNotifier.new);

final filteredAgentsProvider = Provider<List<Agent>>((ref) {
  final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
  final q = ref.watch(agentQueryProvider).trim().toLowerCase();
  final list = q.isEmpty
      ? [...agents]
      : agents.where((a) => a.searchIndex.contains(q)).toList();
  list.sort((a, b) => a.code.compareTo(b.code));
  return list;
});

/// Member count per agent, used on the agents table.
final memberCountByAgentProvider = Provider<Map<String, int>>((ref) {
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final counts = <String, int>{};
  for (final m in members) {
    final id = m.agentId;
    if (id == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
});

/// Total collected per agent, used for the "Top Agents" panel.
final collectionByAgentProvider = Provider<Map<String, double>>((ref) {
  final payments = ref.watch(paymentsProvider).value ?? const <Payment>[];
  final totals = <String, double>{};
  for (final p in payments) {
    final id = p.agentId;
    if (id == null || p.status != PaymentStatus.paid) continue;
    totals[id] = (totals[id] ?? 0) + p.amount;
  }
  return totals;
});

// ---------------------------------------------------------------------------
// Payment filtering
// ---------------------------------------------------------------------------

@immutable
class PaymentFilter {
  const PaymentFilter({
    this.query = '',
    this.mode,
    this.status,
    this.kind,
    this.from,
    this.to,
  });

  final String query;
  final PaymentMode? mode;
  final PaymentStatus? status;
  final PaymentKind? kind;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      query.isEmpty &&
      mode == null &&
      status == null &&
      kind == null &&
      from == null &&
      to == null;

  PaymentFilter copyWith({
    String? query,
    PaymentMode? mode,
    PaymentStatus? status,
    PaymentKind? kind,
    DateTime? from,
    DateTime? to,
    bool clearMode = false,
    bool clearStatus = false,
    bool clearKind = false,
    bool clearRange = false,
  }) {
    return PaymentFilter(
      query: query ?? this.query,
      mode: clearMode ? null : (mode ?? this.mode),
      status: clearStatus ? null : (status ?? this.status),
      kind: clearKind ? null : (kind ?? this.kind),
      from: clearRange ? null : (from ?? this.from),
      to: clearRange ? null : (to ?? this.to),
    );
  }
}

class PaymentFilterNotifier extends Notifier<PaymentFilter> {
  @override
  PaymentFilter build() => const PaymentFilter();

  void setQuery(String value) => state = state.copyWith(query: value);
  void setMode(PaymentMode? v) =>
      state = state.copyWith(mode: v, clearMode: v == null);
  void setStatus(PaymentStatus? v) =>
      state = state.copyWith(status: v, clearStatus: v == null);
  void setKind(PaymentKind? v) =>
      state = state.copyWith(kind: v, clearKind: v == null);
  void setRange(DateTime? from, DateTime? to) => state = state.copyWith(
        from: from,
        to: to,
        clearRange: from == null && to == null,
      );
  void clear() => state = const PaymentFilter();
}

final paymentFilterProvider =
    NotifierProvider<PaymentFilterNotifier, PaymentFilter>(
  PaymentFilterNotifier.new,
);

final scopedPaymentsProvider = Provider<List<Payment>>((ref) {
  final payments = ref.watch(paymentsProvider).value ?? const <Payment>[];
  final yojnaId = ref.watch(selectedYojnaIdProvider);
  if (yojnaId == null) return payments;
  return payments.where((p) => p.yojnaId == yojnaId).toList();
});

final filteredPaymentsProvider = Provider<List<Payment>>((ref) {
  final payments = ref.watch(scopedPaymentsProvider);
  final members = ref.watch(memberByIdProvider);
  final f = ref.watch(paymentFilterProvider);
  final q = f.query.trim().toLowerCase();

  final result = payments.where((p) {
    if (f.mode != null && p.mode != f.mode) return false;
    if (f.status != null && p.status != f.status) return false;
    if (f.kind != null && p.kind != f.kind) return false;
    if (f.from != null && p.date.isBefore(f.from!)) return false;
    if (f.to != null && p.date.isAfter(f.to!)) return false;
    if (q.isNotEmpty) {
      final member = members[p.memberId];
      final haystack = [
        p.receiptNo,
        p.reference,
        member?.name ?? '',
        member?.regNo ?? '',
        member?.primaryPhone ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(q)) return false;
    }
    return true;
  }).toList();

  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
});

/// Totals for the payment page summary strip.
@immutable
class PaymentTotals {
  const PaymentTotals({
    required this.count,
    required this.paid,
    required this.pending,
    required this.failed,
  });

  final int count;
  final double paid;
  final double pending;
  final double failed;

  double get total => paid + pending + failed;
}

final paymentTotalsProvider = Provider<PaymentTotals>((ref) {
  final payments = ref.watch(filteredPaymentsProvider);
  var paid = 0.0, pending = 0.0, failed = 0.0;
  for (final p in payments) {
    switch (p.status) {
      case PaymentStatus.paid:
        paid += p.amount;
      case PaymentStatus.pending:
        pending += p.amount;
      case PaymentStatus.failed:
        failed += p.amount;
    }
  }
  return PaymentTotals(
    count: payments.length,
    paid: paid,
    pending: pending,
    failed: failed,
  );
});

// ---------------------------------------------------------------------------
// Closing cases
// ---------------------------------------------------------------------------

class ClosingFilterNotifier extends Notifier<ClosingPayStatus?> {
  @override
  ClosingPayStatus? build() => null;
  void set(ClosingPayStatus? value) => state = value;
}

final closingFilterProvider =
    NotifierProvider<ClosingFilterNotifier, ClosingPayStatus?>(
  ClosingFilterNotifier.new,
);

final scopedClosingCasesProvider = Provider<List<ClosingCase>>((ref) {
  final cases = ref.watch(closingCasesProvider).value ?? const <ClosingCase>[];
  final yojnaId = ref.watch(selectedYojnaIdProvider);
  final scoped =
      yojnaId == null ? [...cases] : cases.where((c) => c.yojnaId == yojnaId).toList();
  scoped.sort((a, b) => b.closingDate.compareTo(a.closingDate));
  return scoped;
});

final filteredClosingCasesProvider = Provider<List<ClosingCase>>((ref) {
  final cases = ref.watch(scopedClosingCasesProvider);
  final status = ref.watch(closingFilterProvider);
  if (status == null) return cases;
  return cases.where((c) => c.payStatus == status).toList();
});

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

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

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final members = ref.watch(scopedMembersProvider);
  final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
  final payments = ref.watch(scopedPaymentsProvider);
  final cases = ref.watch(scopedClosingCasesProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  final prevStart = DateTime(now.year, now.month - 1);

  var monthTotal = 0.0;
  var prevTotal = 0.0;
  for (final p in payments) {
    if (p.status != PaymentStatus.paid) continue;
    if (!p.date.isBefore(monthStart)) {
      monthTotal += p.amount;
    } else if (!p.date.isBefore(prevStart)) {
      prevTotal += p.amount;
    }
  }

  return DashboardStats(
    totalMembers: members.length,
    activeMembers:
        members.where((m) => m.status == MemberStatus.active).length,
    inactiveMembers:
        members.where((m) => m.status == MemberStatus.inactive).length,
    closedMembers: members.where((m) => m.isClosed).length,
    totalAgents: agents.length,
    activeAgents: agents.where((a) => a.isActive).length,
    monthCollection: monthTotal,
    previousMonthCollection: prevTotal,
    pendingClaims: cases
        .where((c) => c.payStatus != ClosingPayStatus.paid)
        .fold<double>(0, (sum, c) => sum + c.pendingAmount),
  );
});

/// Member counts grouped by scheme, ignoring the top-bar scope.
final membersPerYojnaProvider = Provider<Map<String, int>>((ref) {
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final counts = <String, int>{};
  for (final m in members) {
    counts[m.yojnaId] = (counts[m.yojnaId] ?? 0) + 1;
  }
  return counts;
});

/// Paid collection totals for the last six months (oldest first).
final monthlyCollectionProvider = Provider<List<({DateTime month, double total})>>(
  (ref) {
    final payments = ref.watch(scopedPaymentsProvider);
    final now = DateTime.now();
    final buckets = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      buckets[DateTime(now.year, now.month - i)] = 0;
    }
    for (final p in payments) {
      if (p.status != PaymentStatus.paid) continue;
      final key = DateTime(p.date.year, p.date.month);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + p.amount;
      }
    }
    return buckets.entries
        .map((e) => (month: e.key, total: e.value))
        .toList();
  },
);
