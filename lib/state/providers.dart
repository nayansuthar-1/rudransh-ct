import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../core/config/env.dart';
import '../data/models/models.dart';
import '../data/repositories/access_repository.dart';
import '../data/repositories/in_memory_trust_repository.dart';
import '../data/repositories/lookup_repository.dart';
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

/// Invites and login status for agents (owner tools on the Agents page).
final accessRepositoryProvider = Provider<AccessRepository>((ref) {
  if (Env.hasSupabase) {
    return SupabaseAccessRepository(Supabase.instance.client);
  }
  return InMemoryAccessRepository();
});

/// Agent id → login switched on. Agents never invited are absent.
final agentAccessProvider = FutureProvider<Map<String, bool>>((ref) {
  watchBackendData(ref);
  if (!ref.watch(currentUserProvider).isAdmin) return const {};
  return ref.read(accessRepositoryProvider).fetchAgentAccess();
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

  /// Closing groups the member owes a contribution for, oldest first.
  Future<List<MemberDue>> memberDues(String memberId) =>
      _repo.fetchMemberDues(memberId);

  void _changed() => _ref.read(dataRevisionProvider.notifier).bump();
}

final paymentActionsProvider = Provider<PaymentActions>(PaymentActions.new);

// ---------------------------------------------------------------------------
// Approvals (IMPLEMENTATION_PLAN Phase 12)
// ---------------------------------------------------------------------------

/// Everything agents submitted that waits for an admin.
@immutable
class ApprovalQueue {
  const ApprovalQueue({
    required this.members,
    required this.payments,
    required this.cancelRequests,
    this.deathReports = const [],
    this.changeRequests = const [],
    this.handovers = const [],
  });

  static const empty = ApprovalQueue(
    members: [],
    payments: PaymentPage.empty,
    cancelRequests: PaymentPage.empty,
  );

  final List<Member> members;
  final PaymentPage payments;
  final PaymentPage cancelRequests;
  final List<ClosingRequest> deathReports;
  final List<ChangeRequest> changeRequests;

  /// Cash an agent says they handed over (IMPLEMENTATION_PLAN Phase 16).
  final List<CashHandover> handovers;

  int get count =>
      members.length +
      payments.items.length +
      cancelRequests.items.length +
      deathReports.length +
      changeRequests.length +
      handovers.length;
}

final approvalQueueProvider = FutureProvider<ApprovalQueue>((ref) async {
  watchBackendData(ref);
  if (!ref.watch(currentUserProvider).isAdmin) return ApprovalQueue.empty;
  final repo = ref.read(repositoryProvider);
  final members = repo.fetchPendingMembers();
  final payments = repo.fetchPendingPayments();
  final cancels = repo.fetchCancelRequests();
  final reports = repo.fetchPendingClosingRequests();
  final changes = repo.fetchPendingChangeRequests();
  final handovers = repo.fetchPendingHandovers();
  return ApprovalQueue(
    members: await members,
    payments: await payments,
    cancelRequests: await cancels,
    deathReports: await reports,
    changeRequests: await changes,
    handovers: await handovers,
  );
});

class ApprovalActions {
  ApprovalActions(this._ref);

  final Ref _ref;

  TrustRepository get _repo => _ref.read(repositoryProvider);

  Future<T> _run<T>(Future<T> Function(TrustRepository repo) action) async {
    final result = await action(_repo);
    _ref.read(dataRevisionProvider.notifier).bump();
    return result;
  }

  Future<String> approveMember(String id) => _run((r) => r.approveMember(id));
  Future<void> rejectMember(String id, String reason) =>
      _run((r) => r.rejectMember(id, reason));
  Future<void> approvePayment(String id) => _run((r) => r.approvePayment(id));
  Future<void> rejectPayment(String id, String reason) =>
      _run((r) => r.rejectPayment(id, reason));
  Future<void> cancelPayment(String id, String reason) =>
      _run((r) => r.cancelPayment(id, reason));
  Future<void> declineCancelRequest(String id) =>
      _run((r) => r.declineCancelRequest(id));
  Future<int> reassignMembers(String from, String to) =>
      _run((r) => r.reassignMembers(from, to));

  /// Creates the closing case, so the closing list reloads too.
  Future<void> approveDeathReport(
    String id, {
    required String closingGroup,
    double? claimAmount,
  }) async {
    await _run((r) => r.approveClosingRequest(
          id,
          closingGroup: closingGroup,
          claimAmount: claimAmount,
        ));
    _ref.invalidate(closingCasesProvider);
  }

  Future<void> rejectDeathReport(String id, String reason) =>
      _run((r) => r.rejectClosingRequest(id, reason));

  Future<void> confirmHandover(String id) =>
      _run((r) => r.confirmHandover(id));

  /// The receipts unlink, so the money is the agent's to hand over again.
  Future<void> rejectHandover(String id, String reason) =>
      _run((r) => r.rejectHandover(id, reason));
}

final approvalActionsProvider = Provider<ApprovalActions>(ApprovalActions.new);

// ---------------------------------------------------------------------------
// Commission (IMPLEMENTATION_PLAN Phase 16)
// ---------------------------------------------------------------------------

/// Which month the commission report shows; the first of that month.
class CommissionMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime month) => state = DateTime(month.year, month.month);

  void shift(int months) =>
      state = DateTime(state.year, state.month + months);

  /// The office pays commission for months that have started.
  bool get atLatest {
    final now = DateTime.now();
    return !state.isBefore(DateTime(now.year, now.month));
  }
}

final commissionMonthProvider =
    NotifierProvider<CommissionMonthNotifier, DateTime>(
  CommissionMonthNotifier.new,
);

final commissionReportProvider =
    FutureProvider<List<CommissionMonth>>((ref) async {
  watchBackendData(ref);
  if (!ref.watch(currentUserProvider).isAdmin) return const [];
  return ref
      .read(repositoryProvider)
      .fetchCommissionReport(ref.watch(commissionMonthProvider));
});

class CommissionActions {
  CommissionActions(this._ref);

  final Ref _ref;

  /// Owners only; the database refuses anyone else.
  Future<void> markPaid({
    required String agentId,
    required DateTime month,
    double? amount,
    String reference = '',
  }) async {
    await _ref.read(repositoryProvider).markCommissionPaid(
          agentId: agentId,
          month: month,
          amount: amount,
          reference: reference,
        );
    _ref.read(dataRevisionProvider.notifier).bump();
  }
}

final commissionActionsProvider =
    Provider<CommissionActions>(CommissionActions.new);

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

// ---------------------------------------------------------------------------
// Notifications and announcements (IMPLEMENTATION_PLAN Phase 14)
// ---------------------------------------------------------------------------

/// The signed-in user's own notifications, newest first.
///
/// Written by database triggers, so a save anywhere in the app can add to
/// them; [watchBackendData] refreshes the list after every write.
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<AppNotification>> build() {
    watchBackendData(ref);
    return _repo.fetchNotifications();
  }

  Future<void> markRead(int id) async {
    await _repo.markNotificationRead(id);
    await _refresh();
  }

  Future<void> markAllRead() async {
    await _repo.markAllNotificationsRead();
    await _refresh();
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(_repo.fetchNotifications);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// Badge count on the bell. Derived from the list so marking one read updates
/// the badge without a second round trip.
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const <AppNotification>[];
  return list.where((n) => n.isUnread).length;
});

/// Announcements for whoever is signed in.
class AnnouncementsNotifier extends AsyncNotifier<List<Announcement>> {
  TrustRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<List<Announcement>> build() {
    watchBackendData(ref);
    return _repo.fetchAnnouncements();
  }

  /// Admins only. A null [yojnaId] posts to every Yojna.
  Future<void> post({
    required String title,
    String body = '',
    String? yojnaId,
  }) async {
    await _repo.postAnnouncement(title: title, body: body, yojnaId: yojnaId);
    await _refresh();
  }

  Future<void> remove(String id) async {
    await _repo.deleteAnnouncement(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(_repo.fetchAnnouncements);
  }
}

final announcementsProvider =
    AsyncNotifierProvider<AnnouncementsNotifier, List<Announcement>>(
  AnnouncementsNotifier.new,
);

// ---------------------------------------------------------------------------
// Member portal (IMPLEMENTATION_PLAN Phase 15)
// ---------------------------------------------------------------------------

/// The public lookup. Signed out, so it goes through the Edge Function rather
/// than the database.
final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  if (Env.hasSupabase) {
    return EdgeLookupRepository(Supabase.instance.client);
  }
  final repo = ref.read(repositoryProvider);
  if (repo is! InMemoryTrustRepository) {
    throw StateError('Demo lookup needs the in-memory repository.');
  }
  return InMemoryLookupRepository(
    () => repo.membersView,
    () => repo.yojnasView,
    repo.allDues,
  );
});

/// The signed-in member's own record.
final myMembershipProvider = FutureProvider<Membership>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMyMembership();
});

/// The signed-in member's receipts, newest first.
final myPaymentsProvider = FutureProvider<List<Payment>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMyPayments();
});

/// Closing groups the signed-in member still owes for.
final myDuesProvider = FutureProvider<List<MemberDue>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMyDues();
});

/// The member's own closing case, once the office has opened one.
final myClosingCaseProvider = FutureProvider<ClosingCase?>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMyClosingCase();
});

/// Corrections the member has asked for.
final myChangeRequestsProvider = FutureProvider<List<ChangeRequest>>((ref) {
  watchBackendData(ref);
  return ref.read(repositoryProvider).fetchMyChangeRequests();
});

/// Corrections waiting for an admin.
final pendingChangeRequestsProvider =
    FutureProvider<List<ChangeRequest>>((ref) {
  watchBackendData(ref);
  if (!ref.watch(currentUserProvider).isAdmin) return const <ChangeRequest>[];
  return ref.read(repositoryProvider).fetchPendingChangeRequests();
});

/// Writes from the portal and the admin's change-request screen. Each one
/// bumps the data revision so every dependent screen reloads.
class PortalActions {
  PortalActions(this.ref);

  final Ref ref;

  TrustRepository get _repo => ref.read(repositoryProvider);
  void _touch() => ref.read(dataRevisionProvider.notifier).bump();

  Future<void> payByUpi({
    required double amount,
    required String reference,
    String? closingCaseId,
  }) async {
    await _repo.submitUpiPayment(
      amount: amount,
      reference: reference,
      closingCaseId: closingCaseId,
    );
    _touch();
  }

  Future<void> requestChange(ChangeField field, String newValue) async {
    await _repo.requestChange(field, newValue);
    _touch();
  }

  Future<void> approveChange(String id) async {
    await _repo.approveChangeRequest(id);
    _touch();
  }

  Future<void> rejectChange(String id, String reason) async {
    await _repo.rejectChangeRequest(id, reason);
    _touch();
  }
}

final portalActionsProvider = Provider<PortalActions>(PortalActions.new);
