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
  Future<void> deleteYojna(String id) {
    _yojnas.removeWhere((y) => y.id == id);
    return _delayed(null);
  }

  // ---- Members -----------------------------------------------------------

  @override
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
  Future<void> deleteMember(String id) {
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

  @override
  Future<List<Payment>> fetchPayments() =>
      _delayed(List<Payment>.unmodifiable(_payments));

  @override
  Future<Payment> createPayment(Payment payment) {
    final created = payment.id.isEmpty
        ? payment.copyWith(id: 'p_${_uuid.v4()}')
        : payment;
    _payments.insert(0, created);
    return _delayed(created);
  }

  @override
  Future<Payment> updatePayment(Payment payment) {
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
}
