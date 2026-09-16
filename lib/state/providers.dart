import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../core/config/env.dart';
import '../data/models/models.dart';
import '../data/repositories/in_memory_trust_repository.dart';
import '../data/repositories/supabase_trust_repository.dart';
import '../data/repositories/trust_repository.dart';
import 'auth_controller.dart';

/// Single swap point for the backend.
///
/// Uses Supabase when `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` are defined
/// at build time, otherwise the in-memory demo data. Widget tests override it.
final repositoryProvider = Provider<TrustRepository>((ref) {
  if (Env.hasSupabase) {
    return SupabaseTrustRepository(Supabase.instance.client);
  }
  return InMemoryTrustRepository();
});

// ---------------------------------------------------------------------------
// Data revision
// ---------------------------------------------------------------------------

/// Bumped after every create/update/delete.
///
/// Server-backed views (paged lists, totals, dashboard) watch it, so one save
/// refreshes every screen that could show the changed record.
class DataRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider =
    NotifierProvider<DataRevisionNotifier, int>(DataRevisionNotifier.new);

/// Call at the top of a provider that reads records from the backend.
void watchBackendData(Ref ref) {
  ref.watch(sessionUserIdProvider);
  ref.watch(dataRevisionProvider);
}

// ---------------------------------------------------------------------------
// Yojna
// ---------------------------------------------------------------------------

class YojnaListNotifier extends AsyncNotifier<List<Yojna>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Yojna>> build() {
    ref.watch(sessionUserIdProvider);
    return _repo.fetchYojnas();
  }

  Future<void> add(Yojna yojna) async {
    await _repo.createYojna(yojna);
    await _refresh();
  }

  Future<void> edit(Yojna yojna) async {
    await _repo.updateYojna(yojna);
    await _refresh();
  }

  Future<void> remove(String id) async {
    await _repo.deleteYojna(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    ref.invalidateSelf();
    await future;
  }
}

final yojnaListProvider =
    AsyncNotifierProvider<YojnaListNotifier, List<Yojna>>(
  YojnaListNotifier.new,
);

/// Currently selected scheme in the top bar. `null` means "all schemes".
class SelectedYojnaNotifier extends Notifier<String?> {
  /// Distinguishes "admin picked All" from "nothing picked yet", so editing
  /// the scheme list does not silently reset an explicit choice.
  bool _chosenByUser = false;

  @override
  String? build() {
    final yojnas = ref.watch(yojnaListProvider).value;

    if (_chosenByUser) {
      final current = stateOrNull;
      final stillValid =
          current == null || (yojnas?.any((y) => y.id == current) ?? false);
      if (stillValid) return current;
    }

    // Default to the first scheme as soon as the list resolves.
    if (yojnas == null || yojnas.isEmpty) return null;
    return yojnas.first.id;
  }

  void select(String? id) {
    _chosenByUser = true;
    state = id;
  }
}

final selectedYojnaIdProvider =
    NotifierProvider<SelectedYojnaNotifier, String?>(
  SelectedYojnaNotifier.new,
);

final selectedYojnaProvider = Provider<Yojna?>((ref) {
  final id = ref.watch(selectedYojnaIdProvider);
  final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
  if (id == null) return null;
  for (final y in yojnas) {
    if (y.id == id) return y;
  }
  return null;
});

/// Fast lookup map used by tables that need to print a scheme name.
final yojnaByIdProvider = Provider<Map<String, Yojna>>((ref) {
  final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];
  return {for (final y in yojnas) y.id: y};
});

// ---------------------------------------------------------------------------
// Members
// ---------------------------------------------------------------------------

/// Member writes. Lists are read page by page, see `membersPageProvider`.
class MemberActions {
  MemberActions(this._ref);

  final Ref _ref;

  TrustRepository get _repo => _ref.read(repositoryProvider);

  Future<Member> add(Member member) async {
    final created = await _repo.createMember(member);
    _changed();
    return created;
  }

  Future<void> edit(Member member) async {
    await _repo.updateMember(member);
    _changed();
  }

  Future<void> remove(String id) async {
    await _repo.deleteMember(id);
    _changed();
  }

  Future<Member?> findByPhone(String phone) => _repo.findMemberByPhone(phone);

  Future<List<Member>> search(String text, {bool excludeClosed = false}) =>
      _repo.searchMembers(text, excludeClosed: excludeClosed);

  Future<String> nextRegNo(String yojnaId) => _repo.nextRegNo(yojnaId);

  void _changed() => _ref.read(dataRevisionProvider.notifier).bump();
}

final memberActionsProvider = Provider<MemberActions>(MemberActions.new);

// ---------------------------------------------------------------------------
// Agents
// ---------------------------------------------------------------------------

class AgentsNotifier extends AsyncNotifier<List<Agent>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Agent>> build() {
    ref.watch(sessionUserIdProvider);
    return _repo.fetchAgents();
  }

  Future<void> add(Agent agent) async {
    await _repo.createAgent(agent);
    await _refresh();
  }

  Future<void> edit(Agent agent) async {
    await _repo.updateAgent(agent);
    await _refresh();
  }

  /// Also unassigns the agent's members (database `on delete set null`).
  Future<void> remove(String id) async {
    await _repo.deleteAgent(id);
    await _refresh();
  }

  Future<String> nextCode() => _repo.nextAgentCode();

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    ref.invalidateSelf();
    await future;
  }
}

final agentsProvider =
    AsyncNotifierProvider<AgentsNotifier, List<Agent>>(AgentsNotifier.new);

final agentByIdProvider = Provider<Map<String, Agent>>((ref) {
  final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
  return {for (final a in agents) a.id: a};
});

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

/// Payment writes. Lists are read page by page, see `paymentsPageProvider`.
class PaymentActions {
  PaymentActions(this._ref);

  final Ref _ref;

  TrustRepository get _repo => _ref.read(repositoryProvider);

  Future<void> add(Payment payment) async {
    await _repo.createPayment(payment);
    _changed();
  }

  Future<void> edit(Payment payment) async {
    await _repo.updatePayment(payment);
    _changed();
  }

  Future<void> remove(String id) async {
    await _repo.deletePayment(id);
    _changed();
  }

  Future<String> nextReceiptNo() => _repo.nextReceiptNo();

  void _changed() => _ref.read(dataRevisionProvider.notifier).bump();
}

final paymentActionsProvider = Provider<PaymentActions>(PaymentActions.new);

// ---------------------------------------------------------------------------
// Closing cases
// ---------------------------------------------------------------------------

class ClosingCasesNotifier extends AsyncNotifier<List<ClosingCase>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<ClosingCase>> build() {
    ref.watch(sessionUserIdProvider);
    return _repo.fetchClosingCases();
  }

  /// Also marks the member closed (database trigger).
  Future<void> add(ClosingCase value) async {
    await _repo.createClosingCase(value);
    await _refresh();
  }

  Future<void> edit(ClosingCase value) async {
    await _repo.updateClosingCase(value);
    await _refresh();
  }

  /// Also returns the member to active (database trigger).
  Future<void> remove(String id) async {
    await _repo.deleteClosingCase(id);
    await _refresh();
  }

  Future<void> setPayStatus(ClosingCase value, ClosingPayStatus status) async {
    await edit(
      value.copyWith(
        payStatus: status,
        collectedAmount: status == ClosingPayStatus.paid
            ? value.claimAmount
            : value.collectedAmount,
      ),
    );
  }

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    ref.invalidateSelf();
    await future;
  }
}

final closingCasesProvider =
    AsyncNotifierProvider<ClosingCasesNotifier, List<ClosingCase>>(
  ClosingCasesNotifier.new,
);

// ---------------------------------------------------------------------------
// UI preferences
// ---------------------------------------------------------------------------

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() => state =
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Whether the desktop sidebar is pinned open (user preference).
class SidebarPinnedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final sidebarPinnedProvider =
    NotifierProvider<SidebarPinnedNotifier, bool>(SidebarPinnedNotifier.new);
