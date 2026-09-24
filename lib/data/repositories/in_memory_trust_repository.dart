import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'trust_repository.dart';

/// In-memory implementation used by demo builds and widget tests.
///
/// It starts **empty**: a demo build shows the same blank panel a fresh
/// Supabase project does, so every screen can be tested from zero. Tests load
/// their own records with [loadFixture] (see `test/support/seed_data.dart`).
///
/// It fakes a little network latency so loading/empty/error states in the UI
/// are exercised the same way they will be against a real backend.
class InMemoryTrustRepository implements TrustRepository {
  InMemoryTrustRepository({this.latency = const Duration(milliseconds: 260)});

  /// Preloads records. Test-only hook; nothing under `lib/` calls it.
  void loadFixture({
    List<Yojna> yojnas = const [],
    List<Agent> agents = const [],
    List<Member> members = const [],
    List<ClosingCase> closingCases = const [],
    List<Payment> payments = const [],
  }) {
    _yojnas.addAll(yojnas);
    _agents.addAll(agents);
    _members.addAll(members);
    _closingCases.addAll(closingCases);
    _payments.addAll(payments);
  }

  final Duration latency;
  static const _uuid = Uuid();

  final List<Yojna> _yojnas = [];
  final List<Member> _members = [];
  final List<Agent> _agents = [];
  final List<Payment> _payments = [];
  final List<ClosingCase> _closingCases = [];
  final List<ClosingRequest> _closingRequests = [];
  final List<AppNotification> _notifications = [];
  final List<Announcement> _announcements = [];
  int _nextNotificationId = 1;

  Future<T> _delayed<T>(T value) =>
      Future.delayed(latency, () => value);

  int _indexById<T>(List<T> list, String id, String Function(T) idOf) {
    final index = list.indexWhere((e) => idOf(e) == id);
    if (index == -1) throw StateError('Record $id not found');
    return index;
  }

  // ---- Yojna -------------------------------------------------------------

  @override
  Future<List<Yojna>> fetchYojnas() =>
      _delayed(List<Yojna>.unmodifiable(_yojnas));

  @override
  Future<Yojna> createYojna(Yojna yojna) {
    final created = yojna.id.isEmpty
        ? yojna.copyWith(id: 'y_${_uuid.v4()}')
        : yojna;
    _yojnas.add(created);
    return _delayed(created);
  }

  @override
  Future<Yojna> updateYojna(Yojna yojna) {
    _yojnas[_indexById(_yojnas, yojna.id, (y) => y.id)] = yojna;
    return _delayed(yojna);
  }

  @override
  Future<void> deleteYojna(String id) async {
    // Same rule as the database foreign key.
    if (_members.any((m) => m.yojnaId == id)) {
      throw const RepositoryException(
        'This Yojna has members or payments, so it cannot be deleted.',
      );
    }
    _yojnas.removeWhere((y) => y.id == id);
    return _delayed(null);
  }

  // ---- Members -----------------------------------------------------------

  /// Every member. Test helper only; the app pages through [fetchMembersPage].
  Future<List<Member>> fetchMembers() =>
      _delayed(List<Member>.unmodifiable(_members));

  @override
  Future<Member> createMember(Member member) {
    final created = member.id.isEmpty
        ? member.copyWith(id: 'm_${_uuid.v4()}')
        : member;
    _members.insert(0, created);
    return _delayed(created);
  }

  @override
  Future<Member> updateMember(Member member) {
    _members[_indexById(_members, member.id, (m) => m.id)] = member;
    return _delayed(member);
  }

  @override
  Future<void> deleteMember(String id) async {
    // Same rule as the database foreign key: receipts must not be orphaned.
    if (_payments.any((p) => p.memberId == id)) {
      throw const RepositoryException(
        'This member has receipts, so they cannot be deleted. '
        'Mark the member Inactive instead.',
      );
    }
    _members.removeWhere((m) => m.id == id);
    _closingCases.removeWhere((c) => c.memberId == id);
    return _delayed(null);
  }

  @override
  Future<Member?> findMemberByPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    Member? match;
    for (final m in _members) {
      if (m.primaryPhone == digits || m.altPhone == digits) {
        match = m;
        break;
      }
    }
    return _delayed(match);
  }

  @override
  Future<String> nextRegNo(String yojnaId) {
    final yojna = _yojnas.firstWhere(
      (y) => y.id == yojnaId,
      orElse: () => _yojnas.first,
    );
    final year = DateTime.now().year;
    final prefix = '${yojna.code}-$year-';
    final used = _members
        .where((m) => m.regNo.startsWith(prefix))
        .map((m) => int.tryParse(m.regNo.split('-').last) ?? 0);
    final next = (used.isEmpty ? 0 : used.reduce((a, b) => a > b ? a : b)) + 1;
    return _delayed('$prefix${next.toString().padLeft(4, '0')}');
  }

  // ---- Agents ------------------------------------------------------------

  @override
  Future<List<Agent>> fetchAgents() =>
      _delayed(List<Agent>.unmodifiable(_agents));

  @override
  Future<Agent> createAgent(Agent agent) {
    final created =
        agent.id.isEmpty ? agent.copyWith(id: 'a_${_uuid.v4()}') : agent;
    _agents.add(created);
    return _delayed(created);
  }

  @override
  Future<Agent> updateAgent(Agent agent) {
    _agents[_indexById(_agents, agent.id, (a) => a.id)] = agent;
    return _delayed(agent);
  }

  @override
  Future<void> deleteAgent(String id) {
    _agents.removeWhere((a) => a.id == id);
    for (var i = 0; i < _members.length; i++) {
      if (_members[i].agentId == id) {
        _members[i] = _members[i].copyWith(clearAgent: true);
      }
    }
    return _delayed(null);
  }

  @override
  Future<String> nextAgentCode() {
    final used = _agents
        .map((a) => int.tryParse(a.code.split('-').last) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return _delayed('AG-${(used + 1).toString().padLeft(3, '0')}');
  }

  // ---- Payments ----------------------------------------------------------

  /// Every payment. Test helper only; the app pages through [fetchPaymentsPage].
  Future<List<Payment>> fetchPayments() =>
      _delayed(List<Payment>.unmodifiable(_payments));

  /// Same rules as the `payments_check_closing` database trigger.
  void _checkClosingLink(Payment p) {
    final id = p.closingCaseId;
    if (id == null) return;
    if (p.kind != PaymentKind.contribution) {
      throw const RepositoryException('Only a contribution can be for a closing.');
    }
    final found = _closingCases.where((c) => c.id == id).firstOrNull;
    if (found == null || found.yojnaId != p.yojnaId) {
      throw const RepositoryException(
        "That closing is not in this member's Yojna.",
      );
    }
    if (found.memberId == p.memberId) {
      throw const RepositoryException(
        'A member cannot contribute to their own closing.',
      );
    }
  }

  @override
  Future<Payment> createPayment(Payment payment) {
    _checkClosingLink(payment);
    final created = payment.id.isEmpty
        ? payment.copyWith(id: 'p_${_uuid.v4()}')
        : payment;
    _payments.insert(0, created);
    return _delayed(created);
  }

  @override
  Future<Payment> updatePayment(Payment payment) {
    _checkClosingLink(payment);
    _payments[_indexById(_payments, payment.id, (p) => p.id)] = payment;
    return _delayed(payment);
  }

  @override
  Future<void> deletePayment(String id) {
    _payments.removeWhere((p) => p.id == id);
    return _delayed(null);
  }

  @override
  Future<String> nextReceiptNo() {
    final used = _payments
        .map((p) => int.tryParse(p.receiptNo.split('-').last) ?? 0)
        .fold<int>(1000, (a, b) => a > b ? a : b);
    return _delayed('RCP-${used + 1}');
  }

  // ---- Closing cases -----------------------------------------------------

  @override
  Future<List<ClosingCase>> fetchClosingCases() =>
      _delayed(List<ClosingCase>.unmodifiable(_closingCases));

  @override
  Future<ClosingCase> createClosingCase(ClosingCase value) {
    final created =
        value.id.isEmpty ? value.copyWith(id: 'c_${_uuid.v4()}') : value;
    _closingCases.insert(0, created);

    // Keep the member record in sync with the case.
    final index = _members.indexWhere((m) => m.id == created.memberId);
    if (index != -1) {
      _members[index] = _members[index].copyWith(
        status: MemberStatus.closed,
        closingDate: created.closingDate,
        closingGroup: created.closingGroup,
      );
    }
    return _delayed(created);
  }

  @override
  Future<ClosingCase> updateClosingCase(ClosingCase value) {
    _closingCases[_indexById(_closingCases, value.id, (c) => c.id)] = value;
    return _delayed(value);
  }

  @override
  Future<void> deleteClosingCase(String id) {
    final removed = _closingCases.where((c) => c.id == id).toList();
    _closingCases.removeWhere((c) => c.id == id);
    for (final c in removed) {
      final index = _members.indexWhere((m) => m.id == c.memberId);
      if (index != -1) {
        _members[index] = _members[index]
            .copyWith(status: MemberStatus.active, clearClosing: true);
      }
    }
    return _delayed(null);
  }

  // ---- Paged lists and search ----------------------------------------------

  static PageResult<T> _slice<T>(List<T> all, int offset, int limit) {
    final start = offset.clamp(0, all.length);
    final end = (offset + limit).clamp(0, all.length);
    return PageResult(items: all.sublist(start, end), total: all.length);
  }

  List<Member> _queryMembers(MemberQuery q) {
    final text = q.text.trim().toLowerCase();
    final result = _members.where((m) {
      if (q.yojnaId != null && m.yojnaId != q.yojnaId) return false;
      if (text.isNotEmpty && !m.searchIndex.contains(text)) return false;
      if (q.status != null && m.status != q.status) return false;
      if (q.agentId != null && m.agentId != q.agentId) return false;
      if (q.district != null && m.district != q.district) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final byDate = b.joinDate.compareTo(a.joinDate);
        return byDate != 0 ? byDate : b.regNo.compareTo(a.regNo);
      });
    return result;
  }

  @override
  Future<PageResult<Member>> fetchMembersPage(
    MemberQuery query, {
    required int offset,
    required int limit,
  }) =>
      _delayed(_slice(_queryMembers(query), offset, limit));

  @override
  Future<List<Member>> fetchMembersByIds(Iterable<String> ids) {
    final wanted = ids.toSet();
    return _delayed(_members.where((m) => wanted.contains(m.id)).toList());
  }

  @override
  Future<List<Member>> searchMembers(
    String text, {
    int limit = 20,
    bool excludeClosed = false,
  }) {
    final matches = _queryMembers(MemberQuery(text: text))
        .where((m) => !excludeClosed || !m.isClosed)
        .take(limit)
        .toList();
    return _delayed(matches);
  }

  @override
  Future<List<String>> fetchMemberDistricts() {
    final districts = _members
        .map((m) => m.district)
        .where((d) => d.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return _delayed(districts);
  }

  List<Payment> _queryPayments(PaymentQuery q) {
    final text = q.text.trim().toLowerCase();
    final members = {for (final m in _members) m.id: m};
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

    final result = _payments.where((p) {
      if (q.yojnaId != null && p.yojnaId != q.yojnaId) return false;
      if (q.memberId != null && p.memberId != q.memberId) return false;
      if (q.mode != null && p.mode != q.mode) return false;
      if (q.status != null && p.status != q.status) return false;
      if (q.kind != null && p.kind != q.kind) return false;
      if (q.from != null && day(p.date).isBefore(day(q.from!))) return false;
      if (q.to != null && day(p.date).isAfter(day(q.to!))) return false;
      if (text.isNotEmpty) {
        final member = members[p.memberId];
        final haystack =
            '${p.receiptNo} ${p.reference} ${member?.searchIndex ?? ''}'
                .toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.receiptNo.compareTo(a.receiptNo);
      });
    return result;
  }

  @override
  Future<PaymentPage> fetchPaymentsPage(
    PaymentQuery query, {
    required int offset,
    required int limit,
  }) {
    final page = _slice(_queryPayments(query), offset, limit);
    final ids = page.items.map((p) => p.memberId).toSet();
    return _delayed(
      PaymentPage(
        items: page.items,
        total: page.total,
        members: {
          for (final m in _members)
            if (ids.contains(m.id)) m.id: MemberRef.of(m),
        },
      ),
    );
  }

  @override
  Future<PaymentTotals> fetchPaymentTotals(PaymentQuery query) {
    final payments = _queryPayments(query);
    double sum(PaymentStatus s) => payments
        .where((p) => p.status == s && !p.isCancelled)
        .fold<double>(0, (total, p) => total + p.amount);
    return _delayed(
      PaymentTotals(
        count: payments.length,
        paid: sum(PaymentStatus.paid),
        pending: sum(PaymentStatus.pending),
        failed: sum(PaymentStatus.failed),
      ),
    );
  }

  // ---- Aggregates ----------------------------------------------------------

  @override
  Future<DashboardStats> fetchDashboardStats(String? yojnaId) {
    bool inScope(String id) => yojnaId == null || id == yojnaId;
    final members = _members
        .where((m) => inScope(m.yojnaId) && !m.isPending)
        .toList();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final prevStart = DateTime(now.year, now.month - 1);
    var monthTotal = 0.0;
    var prevTotal = 0.0;
    for (final p in _payments) {
      if (!_countsAsPaid(p) || !inScope(p.yojnaId)) continue;
      if (!p.date.isBefore(monthStart)) {
        monthTotal += p.amount;
      } else if (!p.date.isBefore(prevStart)) {
        prevTotal += p.amount;
      }
    }

    int countStatus(MemberStatus s) => members.where((m) => m.status == s).length;

    return _delayed(
      DashboardStats(
        totalMembers: members.length,
        activeMembers: countStatus(MemberStatus.active),
        inactiveMembers: countStatus(MemberStatus.inactive),
        closedMembers: countStatus(MemberStatus.closed),
        totalAgents: _agents.length,
        activeAgents: _agents.where((a) => a.isActive).length,
        monthCollection: monthTotal,
        previousMonthCollection: prevTotal,
        pendingClaims: _closingCases
            .where((c) =>
                inScope(c.yojnaId) && c.payStatus != ClosingPayStatus.paid)
            .fold<double>(0, (sum, c) => sum + c.pendingAmount),
      ),
    );
  }

  @override
  Future<Map<String, int>> fetchMembersPerYojna() {
    final counts = <String, int>{};
    for (final m in _members.where((m) => !m.isPending)) {
      counts[m.yojnaId] = (counts[m.yojnaId] ?? 0) + 1;
    }
    return _delayed(counts);
  }

  @override
  Future<Map<String, int>> fetchMemberCountByAgent() {
    final counts = <String, int>{};
    for (final m in _members.where((m) => !m.isPending)) {
      final id = m.agentId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return _delayed(counts);
  }

  @override
  Future<Map<String, double>> fetchCollectionByAgent() {
    final totals = <String, double>{};
    for (final p in _payments) {
      final id = p.agentId;
      if (id == null || !_countsAsPaid(p)) continue;
      totals[id] = (totals[id] ?? 0) + p.amount;
    }
    return _delayed(totals);
  }

  bool _countsAsPaid(Payment p) =>
      p.status == PaymentStatus.paid && !p.isCancelled;

  // ---- Approvals -----------------------------------------------------------

  PaymentPage _pageOf(List<Payment> payments) {
    final ids = payments.map((p) => p.memberId).toSet();
    return PaymentPage(
      items: payments,
      total: payments.length,
      members: {
        for (final m in _members)
          if (ids.contains(m.id)) m.id: MemberRef.of(m),
      },
    );
  }

  static String _requireReason(String reason) {
    final r = reason.trim();
    if (r.isEmpty) throw const RepositoryException('Give a reason.');
    return r;
  }

  int _pendingMemberIndex(String id) {
    final i = _members.indexWhere((m) => m.id == id && m.isPending);
    if (i == -1) {
      throw const RepositoryException(
        'This member is no longer waiting for approval.',
      );
    }
    return i;
  }

  int _pendingPaymentIndex(String id) {
    final i = _payments.indexWhere(
      (p) => p.id == id && p.status == PaymentStatus.pending && !p.isCancelled,
    );
    if (i == -1) {
      throw const RepositoryException(
        'This payment is no longer waiting for approval.',
      );
    }
    return i;
  }

  @override
  Future<List<Member>> fetchPendingMembers() =>
      _delayed(_members.where((m) => m.isPending).toList());

  @override
  Future<PaymentPage> fetchPendingPayments() => _delayed(_pageOf(_payments
      .where((p) =>
          p.status == PaymentStatus.pending &&
          p.source != PaymentSource.admin &&
          !p.isCancelled)
      .toList()));

  @override
  Future<PaymentPage> fetchCancelRequests() => _delayed(
        _pageOf(_payments.where((p) => p.hasOpenCancelRequest).toList()),
      );

  @override
  Future<String> approveMember(String memberId) async {
    final i = _pendingMemberIndex(memberId);
    final regNo = await nextRegNo(_members[i].yojnaId);
    _members[i] = _members[i]
        .copyWith(status: MemberStatus.active, regNo: regNo, reviewNote: '');
    return _delayed(regNo);
  }

  @override
  Future<void> rejectMember(String memberId, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingMemberIndex(memberId);
    _members[i] =
        _members[i].copyWith(status: MemberStatus.inactive, reviewNote: r);
    for (var j = 0; j < _payments.length; j++) {
      final p = _payments[j];
      if (p.memberId == memberId && p.status == PaymentStatus.pending) {
        _payments[j] = p.copyWith(
          status: PaymentStatus.failed,
          rejectReason: 'Member rejected: $r',
        );
      }
    }
    await _delayed(null);
  }

  @override
  Future<void> approvePayment(String paymentId) async {
    final i = _pendingPaymentIndex(paymentId);
    if (_members.any((m) => m.id == _payments[i].memberId && m.isPending)) {
      throw const RepositoryException('Approve the member first.');
    }
    _payments[i] =
        _payments[i].copyWith(status: PaymentStatus.paid, rejectReason: '');
    final p = _payments[i];
    _notify(
      NotificationKind.paymentApproved,
      'Payment approved',
      'Rs ${p.amount.toStringAsFixed(0)} from ${_memberName(p.memberId)} '
          '(receipt ${p.receiptNo}) is approved.',
      '/agent/collections',
    );
    await _delayed(null);
  }

  @override
  Future<void> rejectPayment(String paymentId, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingPaymentIndex(paymentId);
    _payments[i] =
        _payments[i].copyWith(status: PaymentStatus.failed, rejectReason: r);
    final p = _payments[i];
    _notify(
      NotificationKind.paymentRejected,
      'Payment rejected',
      'Rs ${p.amount.toStringAsFixed(0)} from ${_memberName(p.memberId)} '
          'was rejected. $r',
      '/agent/collections',
    );
    await _delayed(null);
  }

  @override
  Future<void> cancelPayment(String paymentId, String reason) async {
    final r = _requireReason(reason);
    final i = _payments.indexWhere((p) => p.id == paymentId && !p.isCancelled);
    if (i == -1) {
      throw const RepositoryException('This receipt is already cancelled.');
    }
    _payments[i] =
        _payments[i].copyWith(cancelledAt: DateTime.now(), cancelReason: r);
    await _delayed(null);
  }

  @override
  Future<void> declineCancelRequest(String paymentId) async {
    final i =
        _payments.indexWhere((p) => p.id == paymentId && p.hasOpenCancelRequest);
    if (i == -1) {
      throw const RepositoryException(
        'There is no open cancel request for this receipt.',
      );
    }
    _payments[i] = _payments[i].copyWith(clearCancelRequest: true);
    await _delayed(null);
  }

  @override
  Future<int> reassignMembers(String fromAgentId, String toAgentId) async {
    if (fromAgentId == toAgentId) {
      throw const RepositoryException('Choose a different agent.');
    }
    if (!_agents.any((a) => a.id == toAgentId && a.isActive)) {
      throw const RepositoryException(
        'Choose an active agent to move the members to.',
      );
    }
    var moved = 0;
    for (var i = 0; i < _members.length; i++) {
      if (_members[i].agentId == fromAgentId) {
        _members[i] = _members[i].copyWith(agentId: toAgentId);
        _notify(
          NotificationKind.memberAssigned,
          'A member was moved to you',
          '${_members[i].name} is now on your list.',
          '/agent/members',
        );
        moved++;
      }
    }
    return _delayed(moved);
  }

  // ---- Dues and death reports ------------------------------------------------

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Every member's dues per closing group, by the rules of the
  /// `member_dues` view. Also used by [InMemoryAgentRepository].
  List<MemberDue> allDues() {
    final groups = <(String, String), List<ClosingCase>>{};
    for (final c in _closingCases.where((c) => c.closingGroup.isNotEmpty)) {
      groups.putIfAbsent((c.yojnaId, c.closingGroup), () => []).add(c);
    }

    final result = <MemberDue>[];
    for (final cases in groups.values) {
      cases.sort((a, b) => a.closingDate.compareTo(b.closingDate));
      final first = cases.first;
      final caseIds = {for (final c in cases) c.id};
      final yojna = _yojnas.where((y) => y.id == first.yojnaId).firstOrNull;
      if (yojna == null) continue;

      for (final m in _members) {
        if (m.yojnaId != first.yojnaId ||
            m.status != MemberStatus.active ||
            !_day(m.joinDate).isBefore(_day(first.closingDate))) {
          continue;
        }
        double sum(PaymentStatus status) => _payments
            .where((p) =>
                p.memberId == m.id &&
                p.kind == PaymentKind.contribution &&
                p.status == status &&
                !p.isCancelled &&
                caseIds.contains(p.closingCaseId))
            .fold(0, (total, p) => total + p.amount);
        result.add(
          MemberDue(
            memberId: m.id,
            yojnaId: m.yojnaId,
            closingCaseId: first.id,
            closingGroup: first.closingGroup,
            closingDate: first.closingDate,
            amount: yojna.contributionAmount,
            paid: sum(PaymentStatus.paid),
            pending: sum(PaymentStatus.pending),
            memberName: m.name,
            regNo: m.regNo,
            phone: m.primaryPhone,
            village: m.village,
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<List<MemberDue>> fetchMemberDues(String memberId) => _delayed(
        allDues().where((d) => d.memberId == memberId).toList()
          ..sort((a, b) => a.closingDate.compareTo(b.closingDate)),
      );

  ClosingRequest _withMember(ClosingRequest r) {
    final m = _members.where((m) => m.id == r.memberId).firstOrNull;
    return m == null
        ? r
        : r.copyWith(memberName: m.name, memberRegNo: m.regNo, yojnaId: m.yojnaId);
  }

  /// Every death report, newest first. Used by [InMemoryAgentRepository].
  List<ClosingRequest> allClosingRequests() =>
      _closingRequests.map(_withMember).toList();

  /// Stores an agent's report; the agent repository checks the rules.
  Future<ClosingRequest> createClosingRequest(ClosingRequest request) {
    final created = request.copyWith(
      id: request.id.isEmpty ? 'r_${_uuid.v4()}' : request.id,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
    );
    _closingRequests.insert(0, created);
    return _delayed(_withMember(created));
  }

  int _pendingRequestIndex(String id) {
    final i = _closingRequests
        .indexWhere((r) => r.id == id && r.status == RequestStatus.pending);
    if (i == -1) {
      throw const RepositoryException(
        'This report is no longer waiting for a decision.',
      );
    }
    return i;
  }

  @override
  Future<List<ClosingRequest>> fetchPendingClosingRequests() => _delayed(
        _closingRequests.reversed
            .where((r) => r.status == RequestStatus.pending)
            .map(_withMember)
            .toList(),
      );

  @override
  Future<String> approveClosingRequest(
    String requestId, {
    required String closingGroup,
    double? claimAmount,
  }) async {
    if (closingGroup.trim().isEmpty) {
      throw const RepositoryException('Enter the closing group.');
    }
    final i = _pendingRequestIndex(requestId);
    final request = _closingRequests[i];
    final member = _members.firstWhere((m) => m.id == request.memberId);
    if (_closingCases.any((c) => c.memberId == member.id)) {
      throw const RepositoryException(
        'A closing case already exists for this member.',
      );
    }
    final yojna = _yojnas.firstWhere((y) => y.id == member.yojnaId);
    final created = await createClosingCase(
      ClosingCase(
        id: '',
        memberId: member.id,
        yojnaId: member.yojnaId,
        closingDate: request.dateOfDeath,
        closingGroup: closingGroup.trim(),
        claimAmount: claimAmount ?? yojna.claimAmount,
        nomineeName: request.nomineeName,
        remarks: request.remarks,
      ),
    );
    _closingRequests[i] = request.copyWith(
      status: RequestStatus.approved,
      decisionNote: '',
      closingCaseId: created.id,
    );
    _notify(
      NotificationKind.closingApproved,
      'Death report approved',
      'The report for ${member.name} is approved and a closing case is open.',
      '/agent/dues',
    );
    _notify(
      NotificationKind.closingNew,
      'New closing to collect for',
      '${member.name} in ${yojna.name}. '
          'Collect one contribution from each of your members.',
      '/agent/dues',
    );
    return created.id;
  }

  @override
  Future<void> rejectClosingRequest(String requestId, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingRequestIndex(requestId);
    final request = _closingRequests[i];
    _closingRequests[i] =
        request.copyWith(status: RequestStatus.rejected, decisionNote: r);
    _notify(
      NotificationKind.closingRejected,
      'Death report rejected',
      'The report for ${_memberName(request.memberId)} was rejected. $r',
      '/agent/dues',
    );
    await _delayed(null);
  }

  // ---- Notifications and announcements -------------------------------------

  /// Stands in for the database triggers so demo mode behaves like the real
  /// thing: the same events produce the same lines in the panel.
  void _notify(
    NotificationKind kind,
    String title,
    String body,
    String link,
  ) {
    _notifications.add(AppNotification(
      id: _nextNotificationId++,
      kind: kind,
      title: title,
      body: body,
      link: link,
      createdAt: DateTime.now(),
    ));
  }

  String _memberName(String memberId) {
    final i = _members.indexWhere((m) => m.id == memberId);
    return i == -1 ? 'a member' : _members[i].name;
  }

  @override
  Future<List<AppNotification>> fetchNotifications({int limit = 30}) => _delayed(
        _notifications.reversed.take(limit).toList(),
      );

  @override
  Future<int> fetchUnreadCount() =>
      _delayed(_notifications.where((n) => n.isUnread).length);

  @override
  Future<void> markNotificationRead(int id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i != -1 && _notifications[i].isUnread) {
      _notifications[i] = _notifications[i].copyWith(readAt: DateTime.now());
    }
    await _delayed(null);
  }

  @override
  Future<int> markAllNotificationsRead() async {
    var changed = 0;
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].isUnread) {
        _notifications[i] = _notifications[i].copyWith(readAt: DateTime.now());
        changed++;
      }
    }
    return _delayed(changed);
  }

  @override
  Future<List<Announcement>> fetchAnnouncements({int limit = 20}) => _delayed(
        _announcements.reversed.take(limit).toList(),
      );

  @override
  Future<String> postAnnouncement({
    required String title,
    String body = '',
    String? yojnaId,
  }) async {
    final t = title.trim();
    if (t.isEmpty) {
      throw const RepositoryException('Give the announcement a title.');
    }
    final id = 'ann-${_announcements.length + 1}';
    _announcements.add(Announcement(
      id: id,
      title: t,
      body: body,
      yojnaId: yojnaId,
      yojnaName: yojnaId == null
          ? ''
          : _yojnas.firstWhere((y) => y.id == yojnaId).name,
      publishedAt: DateTime.now(),
    ));
    return _delayed(id);
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    final before = _announcements.length;
    _announcements.removeWhere((a) => a.id == id);
    if (_announcements.length == before) {
      throw const RepositoryException('That announcement is already gone.');
    }
    await _delayed(null);
  }

  // ---- Member portal -------------------------------------------------------

  /// Which member the portal screens belong to. The real backend takes this
  /// from the session; demo mode and tests set it, or fall back to the first
  /// active member so the screens have something to show.
  String? portalMemberId;

  /// Live views for [InMemoryLookupRepository], which needs the records
  /// without awaiting the fake latency.
  List<Member> get membersView => List.unmodifiable(_members);
  List<Yojna> get yojnasView => List.unmodifiable(_yojnas);
  List<Payment> get paymentsView => List.unmodifiable(_payments);
  List<Agent> get agentsView => List.unmodifiable(_agents);

  final List<ChangeRequest> _changeRequests = [];

  Member get _portalMember {
    final id = portalMemberId;
    final found = id == null
        ? _members.where((m) => m.status == MemberStatus.active).firstOrNull
        : _members.where((m) => m.id == id).firstOrNull;
    if (found == null) {
      throw const RepositoryException('Only a member can do this.');
    }
    return found;
  }

  @override
  Future<Membership> fetchMyMembership() {
    final m = _portalMember;
    final yojna = _yojnas.firstWhere((y) => y.id == m.yojnaId);
    final agent = _agents.where((a) => a.id == m.agentId).firstOrNull;
    return _delayed(Membership(
      memberId: m.id,
      regNo: m.regNo,
      name: m.name,
      fatherOrHusbandName: m.fatherOrHusbandName,
      warisName: m.warisName,
      warisRelation: m.warisRelation,
      primaryPhone: m.primaryPhone,
      altPhone: m.altPhone,
      village: m.village,
      tehsil: m.tehsil,
      district: m.district,
      pincode: m.pincode,
      yojnaId: m.yojnaId,
      yojnaName: yojna.name,
      contributionAmount: yojna.contributionAmount,
      joinDate: m.joinDate,
      status: m.status,
      agentName: agent?.name ?? '',
    ));
  }

  @override
  Future<List<Payment>> fetchMyPayments({int limit = 50}) {
    final id = _portalMember.id;
    final mine = _payments.where((p) => p.memberId == id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return _delayed(mine.take(limit).toList());
  }

  @override
  Future<List<MemberDue>> fetchMyDues() {
    final id = _portalMember.id;
    return _delayed(
      allDues().where((d) => d.memberId == id && d.due > 0).toList()
        ..sort((a, b) => a.closingDate.compareTo(b.closingDate)),
    );
  }

  @override
  Future<ClosingCase?> fetchMyClosingCase() {
    final id = _portalMember.id;
    return _delayed(_closingCases.where((c) => c.memberId == id).firstOrNull);
  }

  @override
  Future<String> submitUpiPayment({
    required double amount,
    required String reference,
    String? closingCaseId,
  }) async {
    final m = _portalMember;
    final ref = reference.trim();
    if (amount <= 0) {
      throw const RepositoryException('Enter the amount you paid.');
    }
    if (ref.length < 6) {
      throw const RepositoryException(
        'Enter the UPI reference (UTR) from your payment app.',
      );
    }
    if (_payments.any((p) => p.memberId == m.id && p.reference == ref && !p.isCancelled)) {
      throw const RepositoryException('That UPI reference is already recorded.');
    }
    final created = await createPayment(Payment(
      id: '',
      receiptNo: await nextReceiptNo(),
      memberId: m.id,
      yojnaId: m.yojnaId,
      amount: amount,
      date: DateTime.now(),
      mode: PaymentMode.upi,
      status: PaymentStatus.pending,
      kind: closingCaseId == null
          ? PaymentKind.registration
          : PaymentKind.contribution,
      reference: ref,
      source: PaymentSource.member,
      closingCaseId: closingCaseId,
    ));
    return created.id;
  }

  @override
  Future<String> requestChange(ChangeField field, String newValue) async {
    final m = _portalMember;
    final value = newValue.trim();
    if (value.isEmpty) {
      throw const RepositoryException('Enter the new value.');
    }
    if (_changeRequests.any((r) =>
        r.memberId == m.id &&
        r.field == field &&
        r.status == RequestStatus.pending)) {
      throw const RepositoryException(
        'A change to this detail is already waiting for the office.',
      );
    }
    final id = 'chg-${_changeRequests.length + 1}';
    _changeRequests.add(ChangeRequest(
      id: id,
      memberId: m.id,
      memberName: m.name,
      regNo: m.regNo,
      field: field,
      oldValue: _currentValue(m, field),
      newValue: value,
      createdAt: DateTime.now(),
    ));
    return _delayed(id);
  }

  static String _currentValue(Member m, ChangeField field) => switch (field) {
        ChangeField.primaryPhone => m.primaryPhone,
        ChangeField.altPhone => m.altPhone,
        ChangeField.village => m.village,
        ChangeField.tehsil => m.tehsil,
        ChangeField.district => m.district,
        ChangeField.pincode => m.pincode,
        ChangeField.warisName => m.warisName,
        ChangeField.warisRelation => m.warisRelation,
        ChangeField.name => m.name,
        ChangeField.fatherOrHusbandName => m.fatherOrHusbandName,
      };

  static Member _withValue(Member m, ChangeField field, String v) =>
      switch (field) {
        ChangeField.primaryPhone => m.copyWith(primaryPhone: v),
        ChangeField.altPhone => m.copyWith(altPhone: v),
        ChangeField.village => m.copyWith(village: v),
        ChangeField.tehsil => m.copyWith(tehsil: v),
        ChangeField.district => m.copyWith(district: v),
        ChangeField.pincode => m.copyWith(pincode: v),
        ChangeField.warisName => m.copyWith(warisName: v),
        ChangeField.warisRelation => m.copyWith(warisRelation: v),
        ChangeField.name => m.copyWith(name: v),
        ChangeField.fatherOrHusbandName => m.copyWith(fatherOrHusbandName: v),
      };

  @override
  Future<List<ChangeRequest>> fetchMyChangeRequests() {
    final id = _portalMember.id;
    return _delayed(
      _changeRequests.where((r) => r.memberId == id).toList().reversed.toList(),
    );
  }

  @override
  Future<List<ChangeRequest>> fetchPendingChangeRequests() => _delayed(
        _changeRequests
            .where((r) => r.status == RequestStatus.pending)
            .toList(),
      );

  int _pendingChangeIndex(String id) {
    final i = _changeRequests.indexWhere(
      (r) => r.id == id && r.status == RequestStatus.pending,
    );
    if (i == -1) {
      throw const RepositoryException(
        'This change is no longer waiting for a decision.',
      );
    }
    return i;
  }

  @override
  Future<void> approveChangeRequest(String id) async {
    final i = _pendingChangeIndex(id);
    final request = _changeRequests[i];
    final m = _indexById(_members, request.memberId, (m) => m.id);
    _members[m] = _withValue(_members[m], request.field, request.newValue);
    _changeRequests[i] = ChangeRequest(
      id: request.id,
      memberId: request.memberId,
      memberName: request.memberName,
      regNo: request.regNo,
      field: request.field,
      oldValue: request.oldValue,
      newValue: request.newValue,
      status: RequestStatus.approved,
      createdAt: request.createdAt,
    );
    _notify(
      NotificationKind.other,
      'Your correction was applied',
      '${request.field.label} is now "${request.newValue}".',
      '/me',
    );
    await _delayed(null);
  }

  @override
  Future<void> rejectChangeRequest(String id, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingChangeIndex(id);
    final request = _changeRequests[i];
    _changeRequests[i] = ChangeRequest(
      id: request.id,
      memberId: request.memberId,
      memberName: request.memberName,
      regNo: request.regNo,
      field: request.field,
      oldValue: request.oldValue,
      newValue: request.newValue,
      status: RequestStatus.rejected,
      decisionNote: r,
      createdAt: request.createdAt,
    );
    _notify(
      NotificationKind.other,
      'Your correction was not applied',
      r,
      '/me',
    );
    await _delayed(null);
  }

  // ---- Cash handovers and commission (IMPLEMENTATION_PLAN Phase 16) --------

  final List<CashHandover> _handovers = [];

  /// Commission marked paid, keyed by agent id and the first of the month.
  final Map<String, CommissionMonth> _payouts = {};

  static String _payoutKey(String agentId, DateTime month) =>
      '$agentId@${month.year}-${month.month}';

  /// Approved cash the agent has not declared yet, oldest first. The same
  /// rule as `cash_in_hand()`: approved, not cancelled, cash, unlinked.
  List<Payment> openCashOf(String agentId) => (_payments
          .where((p) =>
              p.agentId == agentId &&
              p.status == PaymentStatus.paid &&
              !p.isCancelled &&
              p.mode == PaymentMode.cash &&
              p.cashHandoverId == null)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date)))
      .toList();

  double cashInHandOf(String agentId) =>
      openCashOf(agentId).fold(0, (sum, p) => sum + p.amount);

  double handoverWaitingOf(String agentId) => _handovers
      .where((h) => h.agentId == agentId && h.status == RequestStatus.pending)
      .fold(0, (sum, h) => sum + h.amount);

  List<CashHandover> handoversOf(String agentId) =>
      _handovers.where((h) => h.agentId == agentId).toList().reversed.toList();

  /// What the agent collected in [month], before the percentage. Claim payouts
  /// are money going out and never count.
  double commissionBaseOf(String agentId, DateTime month) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    return _payments
        .where((p) =>
            p.agentId == agentId &&
            p.status == PaymentStatus.paid &&
            !p.isCancelled &&
            p.kind != PaymentKind.closingPayout &&
            !p.date.isBefore(from) &&
            p.date.isBefore(to))
        .fold(0, (sum, p) => sum + p.amount);
  }

  CommissionMonth commissionOf(String agentId, DateTime month) {
    final agent = _agents.firstWhere((a) => a.id == agentId);
    final first = DateTime(month.year, month.month);
    final collected = commissionBaseOf(agentId, first);
    final paid = _payouts[_payoutKey(agentId, first)];
    return CommissionMonth(
      month: first,
      agentId: agent.id,
      agentCode: agent.code,
      agentName: agent.name,
      collected: collected,
      percent: agent.commissionPercent,
      // Rounded to the paisa, like `commission_of()`.
      amount: (collected * agent.commissionPercent / 100 * 100).round() / 100,
      paidAt: paid?.paidAt,
      paidAmount: paid?.paidAmount,
      reference: paid?.reference ?? '',
    );
  }

  /// Declares cash handed to the office. An empty [paymentIds] means every
  /// open receipt. Returns the amount declared.
  double declareHandover(
    String agentId, {
    List<String> paymentIds = const [],
    String note = '',
  }) {
    final open = openCashOf(agentId);
    final chosen = paymentIds.isEmpty
        ? open
        : open.where((p) => paymentIds.contains(p.id)).toList();
    if (chosen.isEmpty) {
      throw const RepositoryException(
        'There is no cash waiting to be handed over.',
      );
    }
    if (paymentIds.isNotEmpty && chosen.length != paymentIds.toSet().length) {
      throw const RepositoryException(
        'One of those receipts is not yours, or is already in a handover.',
      );
    }

    final id = 'ho-${_handovers.length + 1}';
    final amount = chosen.fold<double>(0, (sum, p) => sum + p.amount);
    final agent = _agents.firstWhere((a) => a.id == agentId);
    _handovers.add(CashHandover(
      id: id,
      agentId: agentId,
      agentCode: agent.code,
      agentName: agent.name,
      amount: amount,
      note: note.trim(),
      declaredAt: DateTime.now(),
      receiptCount: chosen.length,
    ));
    for (final p in chosen) {
      _payments[_indexById(_payments, p.id, (p) => p.id)] =
          p.copyWith(cashHandoverId: id);
    }
    return amount;
  }

  @override
  Future<List<CashHandover>> fetchPendingHandovers() => _delayed(
        _handovers
            .where((h) => h.status == RequestStatus.pending)
            .toList(),
      );

  int _pendingHandoverIndex(String id) {
    final i = _handovers.indexWhere(
      (h) => h.id == id && h.status == RequestStatus.pending,
    );
    if (i == -1) {
      throw const RepositoryException(
        'This handover is no longer waiting for a decision.',
      );
    }
    return i;
  }

  CashHandover _decided(
    CashHandover h, {
    required RequestStatus status,
    String decisionNote = '',
    DateTime? confirmedAt,
  }) =>
      CashHandover(
        id: h.id,
        agentId: h.agentId,
        agentCode: h.agentCode,
        agentName: h.agentName,
        amount: h.amount,
        note: h.note,
        status: status,
        decisionNote: decisionNote,
        declaredAt: h.declaredAt,
        confirmedAt: confirmedAt,
        receiptCount: h.receiptCount,
      );

  @override
  Future<void> confirmHandover(String id) async {
    final i = _pendingHandoverIndex(id);
    _handovers[i] = _decided(
      _handovers[i],
      status: RequestStatus.approved,
      confirmedAt: DateTime.now(),
    );
    _notify(
      NotificationKind.handoverConfirmed,
      'Cash handover confirmed',
      'The office received Rs ${_handovers[i].amount.toStringAsFixed(0)}.',
      '/agent/collections',
    );
    await _delayed(null);
  }

  @override
  Future<void> rejectHandover(String id, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingHandoverIndex(id);
    _handovers[i] = _decided(
      _handovers[i],
      status: RequestStatus.rejected,
      decisionNote: r,
    );
    // The receipts unlink, so the money goes back to the agent's hand.
    for (var j = 0; j < _payments.length; j++) {
      if (_payments[j].cashHandoverId == id) {
        _payments[j] = _payments[j].copyWith(clearHandover: true);
      }
    }
    _notify(
      NotificationKind.handoverRejected,
      'Cash handover not confirmed',
      r,
      '/agent/collections',
    );
    await _delayed(null);
  }

  @override
  Future<List<CommissionMonth>> fetchCommissionReport(DateTime month) {
    final first = DateTime(month.year, month.month);
    final rows = _agents
        .where((a) =>
            a.isActive || _payouts.containsKey(_payoutKey(a.id, first)))
        .map((a) => commissionOf(a.id, first))
        .toList()
      ..sort((a, b) => a.agentName.compareTo(b.agentName));
    return _delayed(rows);
  }

  @override
  Future<Map<String, dynamic>> exportMemberData(String memberId) {
    final i = _indexById(_members, memberId, (m) => m.id);
    final m = _members[i];
    return _delayed({
      'exported_at': DateTime.now().toIso8601String(),
      'member': m.toMap(),
      'yojna': _yojnas
          .where((y) => y.id == m.yojnaId)
          .map((y) => {'name': y.name, 'code': y.code})
          .firstOrNull,
      'agent': _agents
          .where((a) => a.id == m.agentId)
          .map((a) => {'name': a.name, 'code': a.code})
          .firstOrNull,
      'payments': [
        for (final p in _payments.where((p) => p.memberId == memberId))
          p.toMap(),
      ],
    });
  }

  @override
  Future<void> eraseMemberData(String memberId, String reason) async {
    final r = _requireReason(reason);
    final i = _indexById(_members, memberId, (m) => m.id);
    // The same anonymising the database does: the receipts stay, the person
    // does not.
    _members[i] = _members[i].copyWith(
      name: 'Erased member',
      fatherOrHusbandName: '',
      jati: '',
      gotra: '',
      clearDob: true,
      warisName: '',
      warisRelation: '',
      primaryPhone: '0000000000',
      altPhone: '',
      aadhaar: '',
      village: '',
      tehsil: '',
      district: '',
      state: '',
      pincode: '',
      status: MemberStatus.inactive,
      reviewNote: 'Erased on request: $r',
    );
    await _delayed(null);
  }

  /// Demo mode keeps the number in the clear, so there is nothing to decrypt.
  @override
  Future<String> fetchMemberAadhaar(String memberId) {
    final found = _members.where((m) => m.id == memberId);
    if (found.isEmpty) {
      throw const RepositoryException('Member not found.');
    }
    return _delayed(found.first.aadhaar);
  }

  @override
  Future<void> markCommissionPaid({
    required String agentId,
    required DateTime month,
    double? amount,
    String reference = '',
  }) async {
    final first = DateTime(month.year, month.month);
    final now = DateTime.now();
    if (first.isAfter(DateTime(now.year, now.month))) {
      throw const RepositoryException('That month has not started yet.');
    }
    final calculated = commissionOf(agentId, first);
    final paid = amount ?? calculated.amount;
    if (paid < 0) {
      throw const RepositoryException('The amount cannot be negative.');
    }
    _payouts[_payoutKey(agentId, first)] = CommissionMonth(
      month: first,
      agentId: agentId,
      collected: calculated.collected,
      percent: calculated.percent,
      amount: calculated.amount,
      paidAt: now,
      paidAmount: paid,
      reference: reference.trim(),
    );
    _notify(
      NotificationKind.commissionPaid,
      'Commission paid',
      'Rs ${paid.toStringAsFixed(0)} for ${first.month}/${first.year}.',
      '/agent/collections',
    );
    await _delayed(null);
  }
}
