import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../seed/seed_data.dart';
import 'trust_repository.dart';

/// In-memory implementation backed by [SeedData].
///
/// It fakes a little network latency so loading/empty/error states in the UI
/// are exercised the same way they will be against a real backend.
class InMemoryTrustRepository implements TrustRepository {
  InMemoryTrustRepository({this.latency = const Duration(milliseconds: 260)}) {
    _agents.addAll(SeedData.agents());
    _members.addAll(SeedData.members(_agents));
    _closingCases.addAll(SeedData.closingCases(_members));
    _payments.addAll(SeedData.payments(_members));
    _yojnas.addAll(SeedData.yojnas);
  }

  final Duration latency;
  static const _uuid = Uuid();

  final List<Yojna> _yojnas = [];
  final List<Member> _members = [];
  final List<Agent> _agents = [];
  final List<Payment> _payments = [];
  final List<ClosingCase> _closingCases = [];
  final List<ClosingRequest> _closingRequests = [];

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
    await _delayed(null);
  }

  @override
  Future<void> rejectPayment(String paymentId, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingPaymentIndex(paymentId);
    _payments[i] =
        _payments[i].copyWith(status: PaymentStatus.failed, rejectReason: r);
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
    return created.id;
  }

  @override
  Future<void> rejectClosingRequest(String requestId, String reason) async {
    final r = _requireReason(reason);
    final i = _pendingRequestIndex(requestId);
    _closingRequests[i] = _closingRequests[i]
        .copyWith(status: RequestStatus.rejected, decisionNote: r);
    await _delayed(null);
  }
}
