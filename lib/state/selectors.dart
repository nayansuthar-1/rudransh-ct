import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'providers.dart';

/// Rows per page for the members and payments tables.
const listPageSize = 20;

/// Waits out fast typing before a search hits the backend. Returns false when
/// a newer keystroke has already replaced this request.
Future<bool> _settled(Ref ref, String text) async {
  if (text.trim().isEmpty) return true;
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return ref.mounted;
}

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

/// Top-bar scheme scope plus the members page filters.
final memberQueryProvider = Provider<MemberQuery>((ref) {
  final f = ref.watch(memberFilterProvider);
  return MemberQuery(
    yojnaId: ref.watch(selectedYojnaIdProvider),
    text: f.query.trim(),
    status: f.status,
    agentId: f.agentId,
    district: f.district,
  );
});

/// Zero-based page of the members table. Resets when the query changes.
class MemberPageNotifier extends Notifier<int> {
  @override
  int build() {
    ref.watch(memberQueryProvider);
    return 0;
  }

  void set(int page) => state = page;
}

final memberPageProvider =
    NotifierProvider<MemberPageNotifier, int>(MemberPageNotifier.new);

final membersPageProvider = FutureProvider<PageResult<Member>>((ref) async {
  watchBackendData(ref);
  final query = ref.watch(memberQueryProvider);
  final page = ref.watch(memberPageProvider);
  if (!await _settled(ref, query.text)) return PageResult.empty();
  return ref.read(repositoryProvider).fetchMembersPage(
        query,
        offset: page * listPageSize,
        limit: listPageSize,
      );
});

final memberDistrictsProvider = FutureProvider<List<String>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMemberDistricts();
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
final memberCountByAgentProvider = FutureProvider<Map<String, int>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMemberCountByAgent();
});

/// Total collected per agent, used for the "Top Agents" panel.
final collectionByAgentProvider = FutureProvider<Map<String, double>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchCollectionByAgent();
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

final paymentQueryProvider = Provider<PaymentQuery>((ref) {
  final f = ref.watch(paymentFilterProvider);
  return PaymentQuery(
    yojnaId: ref.watch(selectedYojnaIdProvider),
    text: f.query.trim(),
    mode: f.mode,
    status: f.status,
    kind: f.kind,
    from: f.from,
    to: f.to,
  );
});

/// Zero-based page of the payments table. Resets when the query changes.
class PaymentPageNotifier extends Notifier<int> {
  @override
  int build() {
    ref.watch(paymentQueryProvider);
    return 0;
  }

  void set(int page) => state = page;
}

final paymentPageProvider =
    NotifierProvider<PaymentPageNotifier, int>(PaymentPageNotifier.new);

final paymentsPageProvider = FutureProvider<PaymentPage>((ref) async {
  watchBackendData(ref);
  final query = ref.watch(paymentQueryProvider);
  final page = ref.watch(paymentPageProvider);
  if (!await _settled(ref, query.text)) return PaymentPage.empty;
  return ref.read(repositoryProvider).fetchPaymentsPage(
        query,
        offset: page * listPageSize,
        limit: listPageSize,
      );
});

/// Totals for the payment page summary strip, across all pages.
final paymentTotalsProvider = FutureProvider<PaymentTotals>((ref) async {
  watchBackendData(ref);
  final query = ref.watch(paymentQueryProvider);
  if (!await _settled(ref, query.text)) return PaymentTotals.empty;
  return ref.read(repositoryProvider).fetchPaymentTotals(query);
});

/// Latest payments in the top-bar scope, for the dashboard.
final recentPaymentsProvider = FutureProvider<PaymentPage>((ref) {
  watchBackendData(ref);
  final yojnaId = ref.watch(selectedYojnaIdProvider);
  return ref
      .read(repositoryProvider)
      .fetchPaymentsPage(PaymentQuery(yojnaId: yojnaId), offset: 0, limit: 6);
});

/// Latest payments of one member, for the member detail sheet.
final memberRecentPaymentsProvider =
    FutureProvider.autoDispose.family<PaymentPage, String>((ref, memberId) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchPaymentsPage(
        PaymentQuery(memberId: memberId),
        offset: 0,
        limit: 6,
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

/// The members behind the closing cases, keyed by id.
final closingMembersProvider = FutureProvider<Map<String, Member>>((ref) async {
  watchBackendData(ref);
  final cases = await ref.watch(closingCasesProvider.future);
  if (cases.isEmpty) return const {};
  final members = await ref
      .read(repositoryProvider)
      .fetchMembersByIds(cases.map((c) => c.memberId));
  return {for (final m in members) m.id: m};
});

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

/// Stat tiles for the scheme selected in the top bar.
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) {
  watchBackendData(ref);
  final yojnaId = ref.watch(selectedYojnaIdProvider);
  return ref.read(repositoryProvider).fetchDashboardStats(yojnaId);
});

/// Member counts grouped by scheme, ignoring the top-bar scope.
final membersPerYojnaProvider = FutureProvider<Map<String, int>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMembersPerYojna();
});
