import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../core/config/env.dart';
import '../data/models/models.dart';
import '../data/repositories/agent_repository.dart';
import '../data/repositories/in_memory_trust_repository.dart';
import 'auth_controller.dart';
import 'providers.dart';

/// State for the agent screens (IMPLEMENTATION_PLAN Phase 12).

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  if (Env.hasSupabase) {
    return SupabaseAgentRepository(Supabase.instance.client);
  }
  final base = ref.watch(repositoryProvider);
  return InMemoryAgentRepository(
    base is InMemoryTrustRepository ? base : InMemoryTrustRepository(),
    agentId: ref.watch(currentUserProvider).agentId,
  );
});

const agentListPageSize = 20;

bool _signedInAsAgent(Ref ref) =>
    ref.watch(currentUserProvider).role == UserRole.agent;

final agentSummaryProvider = FutureProvider<AgentSummary>((ref) {
  watchBackendData(ref);
  if (!_signedInAsAgent(ref)) return AgentSummary.empty;
  return ref.read(agentRepositoryProvider).fetchSummary();
});

final agentYojnasProvider = FutureProvider<List<Yojna>>((ref) {
  ref.watch(sessionUserIdProvider);
  if (!_signedInAsAgent(ref)) return const [];
  return ref.read(agentRepositoryProvider).fetchMyYojnas();
});

/// A value the screens set, e.g. a search text or a status filter.
class ValueHolder<T> extends Notifier<T> {
  ValueHolder(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

// ---- My Members --------------------------------------------------------------

final agentMemberTextProvider =
    NotifierProvider<ValueHolder<String>, String>(() => ValueHolder(''));

final agentMemberStatusProvider =
    NotifierProvider<ValueHolder<MemberStatus?>, MemberStatus?>(
  () => ValueHolder(null),
);

/// Zero-based page; back to the first page when a filter changes.
class FilteredPage extends Notifier<int> {
  FilteredPage(this._filters);

  final void Function(Ref ref) _filters;

  @override
  int build() {
    _filters(ref);
    return 0;
  }

  void set(int page) => state = page;
}

final agentMemberPageProvider = NotifierProvider<FilteredPage, int>(
  () => FilteredPage((ref) {
    ref.watch(agentMemberTextProvider);
    ref.watch(agentMemberStatusProvider);
  }),
);

final agentMembersProvider = FutureProvider<PageResult<Member>>((ref) async {
  watchBackendData(ref);
  if (!_signedInAsAgent(ref)) return PageResult.empty();
  final text = ref.watch(agentMemberTextProvider);
  final status = ref.watch(agentMemberStatusProvider);
  final page = ref.watch(agentMemberPageProvider);
  if (text.trim().isNotEmpty) {
    // Wait for typing to pause.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!ref.mounted) return PageResult.empty();
  }
  return ref.read(agentRepositoryProvider).fetchMyMembers(
        text: text,
        status: status,
        offset: page * agentListPageSize,
        limit: agentListPageSize,
      );
});

// ---- Collections -------------------------------------------------------------

final agentPaymentStatusProvider =
    NotifierProvider<ValueHolder<PaymentStatus?>, PaymentStatus?>(
  () => ValueHolder(null),
);

final agentPaymentPageProvider = NotifierProvider<FilteredPage, int>(
  () => FilteredPage((ref) => ref.watch(agentPaymentStatusProvider)),
);

final agentPaymentsProvider = FutureProvider<PaymentPage>((ref) {
  watchBackendData(ref);
  if (!_signedInAsAgent(ref)) return PaymentPage.empty;
  return ref.read(agentRepositoryProvider).fetchMyPayments(
        status: ref.watch(agentPaymentStatusProvider),
        offset: ref.watch(agentPaymentPageProvider) * agentListPageSize,
        limit: agentListPageSize,
      );
});

// ---- Writes --------------------------------------------------------------------

class AgentActions {
  AgentActions(this._ref);

  final Ref _ref;

  AgentRepository get _repo => _ref.read(agentRepositoryProvider);

  Future<T> _run<T>(Future<T> Function(AgentRepository repo) action) async {
    final result = await action(_repo);
    _ref.read(dataRevisionProvider.notifier).bump();
    return result;
  }

  Future<void> addMember(Member member) => _run((r) => r.addMember(member));

  Future<void> updateContact(Member member) =>
      _run((r) => r.updateContact(member));

  /// Returns the receipt number.
  Future<String> recordPayment(Payment payment) =>
      _run((r) => r.recordPayment(payment));

  Future<void> requestCancel(String paymentId, String reason) =>
      _run((r) => r.requestCancel(paymentId, reason));

  /// Search for the payment form's member picker.
  Future<List<Member>> searchMembers(String text) async =>
      (await _repo.fetchMyMembers(text: text, offset: 0, limit: 8)).items;
}

final agentActionsProvider = Provider<AgentActions>(AgentActions.new);
