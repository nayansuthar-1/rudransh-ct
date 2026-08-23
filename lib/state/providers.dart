import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/repositories/in_memory_trust_repository.dart';
import '../data/repositories/trust_repository.dart';

/// Single swap point for the backend.
///
/// Replace [InMemoryTrustRepository] with a Firebase/Supabase/REST
/// implementation of [TrustRepository] and the rest of the app is unchanged.
final repositoryProvider = Provider<TrustRepository>((ref) {
  return InMemoryTrustRepository();
});

// ---------------------------------------------------------------------------
// Yojna
// ---------------------------------------------------------------------------

class YojnaListNotifier extends AsyncNotifier<List<Yojna>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Yojna>> build() => _repo.fetchYojnas();

  Future<void> add(Yojna yojna) async {
    await _repo.createYojna(yojna);
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit(Yojna yojna) async {
    await _repo.updateYojna(yojna);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await _repo.deleteYojna(id);
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

class MembersNotifier extends AsyncNotifier<List<Member>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Member>> build() => _repo.fetchMembers();

  Future<Member> add(Member member) async {
    final created = await _repo.createMember(member);
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<void> edit(Member member) async {
    await _repo.updateMember(member);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await _repo.deleteMember(id);
    ref.invalidateSelf();
    await future;
  }

  Future<Member?> findByPhone(String phone) => _repo.findMemberByPhone(phone);

  Future<String> nextRegNo(String yojnaId) => _repo.nextRegNo(yojnaId);
}

final membersProvider =
    AsyncNotifierProvider<MembersNotifier, List<Member>>(MembersNotifier.new);

final memberByIdProvider = Provider<Map<String, Member>>((ref) {
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  return {for (final m in members) m.id: m};
});

// ---------------------------------------------------------------------------
// Agents
// ---------------------------------------------------------------------------

class AgentsNotifier extends AsyncNotifier<List<Agent>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Agent>> build() => _repo.fetchAgents();

  Future<void> add(Agent agent) async {
    await _repo.createAgent(agent);
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit(Agent agent) async {
    await _repo.updateAgent(agent);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await _repo.deleteAgent(id);
    ref.invalidateSelf();
    ref.invalidate(membersProvider);
    await future;
  }

  Future<String> nextCode() => _repo.nextAgentCode();
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

class PaymentsNotifier extends AsyncNotifier<List<Payment>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Payment>> build() => _repo.fetchPayments();

  Future<void> add(Payment payment) async {
    await _repo.createPayment(payment);
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit(Payment payment) async {
    await _repo.updatePayment(payment);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await _repo.deletePayment(id);
    ref.invalidateSelf();
    await future;
  }

  Future<String> nextReceiptNo() => _repo.nextReceiptNo();
}

final paymentsProvider =
    AsyncNotifierProvider<PaymentsNotifier, List<Payment>>(
  PaymentsNotifier.new,
);

// ---------------------------------------------------------------------------
// Closing cases
// ---------------------------------------------------------------------------

class ClosingCasesNotifier extends AsyncNotifier<List<ClosingCase>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<ClosingCase>> build() => _repo.fetchClosingCases();

  Future<void> add(ClosingCase value) async {
    await _repo.createClosingCase(value);
    ref.invalidateSelf();
    ref.invalidate(membersProvider);
    await future;
  }

  Future<void> edit(ClosingCase value) async {
    await _repo.updateClosingCase(value);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await _repo.deleteClosingCase(id);
    ref.invalidateSelf();
    ref.invalidate(membersProvider);
    await future;
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
