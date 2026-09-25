import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'in_memory_trust_repository.dart';
import 'supabase_trust_repository.dart';
import 'trust_repository.dart' show RepositoryException;

/// Numbers on the agent home page.
@immutable
class AgentSummary {
  const AgentSummary({
    required this.activeMembers,
    required this.pendingMembers,
    required this.pendingPayments,
    required this.pendingAmount,
    required this.monthApproved,
    this.cashInHand = 0,
    this.handoverWaiting = 0,
    this.monthCommission = 0,
  });

  static const empty = AgentSummary(
    activeMembers: 0,
    pendingMembers: 0,
    pendingPayments: 0,
    pendingAmount: 0,
    monthApproved: 0,
  );

  final int activeMembers;
  final int pendingMembers;
  final int pendingPayments;
  final double pendingAmount;

  /// Approved collections this calendar month.
  final double monthApproved;

  /// Approved cash the agent has not handed to the office yet
  /// (IMPLEMENTATION_PLAN Phase 16).
  final double cashInHand;

  /// Declared, waiting for an admin to confirm it.
  final double handoverWaiting;

  /// This month's commission, as it stands today.
  final double monthCommission;
}

/// What a signed-in agent can read and do (IMPLEMENTATION_PLAN Phase 12).
/// Everything is limited to the agent's own members; members come back
/// without Aadhaar.
abstract class AgentRepository {
  Future<AgentSummary> fetchSummary();

  /// Active schemes the agent may enrol members in.
  Future<List<Yojna>> fetchMyYojnas();

  Future<PageResult<Member>> fetchMyMembers({
    String text = '',
    MemberStatus? status,
    required int offset,
    required int limit,
  });

  /// Saved as pending; an admin approves it and issues the reg number.
  Future<void> addMember(Member member);

  /// Phones and address only.
  Future<void> updateContact(Member member);

  /// Saved as pending. Returns the receipt number to give the member.
  Future<String> recordPayment(Payment payment);

  Future<PaymentPage> fetchMyPayments({
    PaymentStatus? status,
    required int offset,
    required int limit,
  });

  Future<void> requestCancel(String paymentId, String reason);

  // ---- Dues and closing reports (IMPLEMENTATION_PLAN Phase 13) ----------------

  /// Closings the agent's members owe for, one row each, newest first.
  Future<PageResult<ClosingDues>> fetchClosings({
    required int offset,
    required int limit,
  });

  /// The agent's members for one closing: still due first, then waiting for
  /// approval, then paid.
  Future<List<MemberDue>> fetchClosingDues(String closingCaseId);

  /// Closings one of the agent's members owes for, oldest first.
  Future<List<MemberDue>> fetchMemberDues(String memberId);

  /// For the office to decide. The proof must already be uploaded.
  Future<void> reportClosing(ClosingRequest request);

  /// Closings the agent reported, newest first.
  Future<List<ClosingRequest>> fetchMyClosingReports();

  // ---- Cash and commission (IMPLEMENTATION_PLAN Phase 16) -------------------

  /// The approved cash receipts that make up cash in hand, oldest first.
  Future<List<OpenCashReceipt>> fetchOpenCash();

  /// Declares cash handed to the office. An empty [paymentIds] means every
  /// open receipt. Returns the amount declared.
  Future<double> declareHandover({
    List<String> paymentIds = const [],
    String note = '',
  });

  /// The agent's own handovers, newest first.
  Future<List<CashHandover>> fetchMyHandovers();

  /// The last [months] calendar months, newest first.
  Future<List<CommissionMonth>> fetchMyCommission({int months = 6});
}

class SupabaseAgentRepository implements AgentRepository {
  SupabaseAgentRepository(this._db);

  final SupabaseClient _db;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw RepositoryException(
        SupabaseTrustRepository.describePostgrestError(e),
      );
    }
  }

  /// PostgREST answers 416 when a range starts past the last row.
  static bool _pastLastPage(PostgrestException e) =>
      e.code == 'PGRST103' || e.code == '416';

  @override
  Future<AgentSummary> fetchSummary() => _guard(() async {
        final rows = await _db.rpc('agent_summary') as List;
        if (rows.isEmpty) return AgentSummary.empty;
        final r = rows.first as Map<String, dynamic>;
        return AgentSummary(
          activeMembers: (r['active_members'] as num).toInt(),
          pendingMembers: (r['pending_members'] as num).toInt(),
          pendingPayments: (r['pending_payments'] as num).toInt(),
          pendingAmount: (r['pending_amount'] as num).toDouble(),
          monthApproved: (r['month_approved'] as num).toDouble(),
          cashInHand: (r['cash_in_hand'] as num?)?.toDouble() ?? 0,
          handoverWaiting: (r['handover_waiting'] as num?)?.toDouble() ?? 0,
          monthCommission: (r['month_commission'] as num?)?.toDouble() ?? 0,
        );
      });

  @override
  Future<List<Yojna>> fetchMyYojnas() => _guard(() async {
        final rows = await _db.rpc('agent_yojnas') as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            Yojna(
              id: r['id'] as String,
              name: r['name'] as String,
              code: r['code'] as String,
              contributionAmount: (r['contribution_amount'] as num).toDouble(),
              description: r['description'] as String? ?? '',
              registrationFee: (r['registration_fee'] as num).toDouble(),
              startDate:
                  r['start_date'] == null ? null : _date(r['start_date']),
              createdAt: DateTime.now(),
            ),
        ];
      });

  @override
  Future<PageResult<Member>> fetchMyMembers({
    String text = '',
    MemberStatus? status,
    required int offset,
    required int limit,
  }) =>
      _guard(() async {
        final params = {'p_query': text.trim(), 'p_status': status?.name};
        try {
          final res = await _db
              .rpc('agent_members', params: params)
              .select()
              .range(offset, offset + limit - 1)
              .count(CountOption.exact);
          return PageResult(
            items: res.data.map(_memberFromRow).toList(),
            total: res.count,
          );
        } on PostgrestException catch (e) {
          if (!_pastLastPage(e)) rethrow;
          return PageResult<Member>(items: const [], total: offset);
        }
      });

  @override
  Future<void> addMember(Member m) => _guard(() => _db.rpc(
        'agent_add_member',
        params: {
          'p_member': {
            'yojna_id': m.yojnaId,
            'name': m.name,
            'father_or_husband_name': m.fatherOrHusbandName,
            'jati': m.jati,
            'gotra': m.gotra,
            'dob': m.dob == null ? null : _dateFormat.format(m.dob!),
            'waris_name': m.warisName,
            'waris_relation': m.warisRelation,
            'gender': m.gender.name,
            'primary_phone': m.primaryPhone,
            'alt_phone': m.altPhone,
            'aadhaar': m.aadhaar,
            'village': m.village,
            'tehsil': m.tehsil,
            'district': m.district,
            'state': m.state,
            'pincode': m.pincode,
            'join_date': _dateFormat.format(m.joinDate),
          },
        },
      ));

  @override
  Future<void> updateContact(Member m) => _guard(() => _db.rpc(
        'agent_update_contact',
        params: {
          'p_member_id': m.id,
          'p_contact': {
            'primary_phone': m.primaryPhone,
            'alt_phone': m.altPhone,
            'village': m.village,
            'tehsil': m.tehsil,
            'district': m.district,
            'state': m.state,
            'pincode': m.pincode,
            'email': m.email,
          },
        },
      ));

  @override
  Future<String> recordPayment(Payment p) => _guard(() async {
        final result = await _db.rpc(
          'agent_record_payment',
          params: {
            'p_payment': {
              'member_id': p.memberId,
              'amount': p.amount,
              'date': _dateFormat.format(p.date),
              'mode': p.mode.name,
              'kind': p.kind.name,
              'reference': p.reference,
              'note': p.note,
              'closing_case_id': p.closingCaseId,
            },
          },
        );
        return (result as Map<String, dynamic>)['receipt_no'] as String;
      });

  @override
  Future<PaymentPage> fetchMyPayments({
    PaymentStatus? status,
    required int offset,
    required int limit,
  }) =>
      _guard(() async {
        try {
          final res = await _db
              .rpc('agent_payments', params: {'p_status': status?.name})
              .select()
              .range(offset, offset + limit - 1)
              .count(CountOption.exact);
          return PaymentPage(
            items: res.data.map(_paymentFromRow).toList(),
            total: res.count,
            members: {
              for (final r in res.data)
                r['member_id'] as String: MemberRef(
                  id: r['member_id'] as String,
                  name: r['member_name'] as String? ?? '',
                  regNo: r['member_reg_no'] as String? ?? '',
                  primaryPhone: r['member_phone'] as String? ?? '',
                ),
            },
          );
        } on PostgrestException catch (e) {
          if (!_pastLastPage(e)) rethrow;
          return PaymentPage(items: const [], total: offset);
        }
      });

  @override
  Future<void> requestCancel(String paymentId, String reason) => _guard(
        () => _db.rpc(
          'agent_request_cancel',
          params: {'p_payment_id': paymentId, 'p_reason': reason},
        ),
      );

  @override
  Future<PageResult<ClosingDues>> fetchClosings({
    required int offset,
    required int limit,
  }) =>
      _guard(() async {
        try {
          final res = await _db
              .rpc('agent_closing_groups')
              .select()
              .range(offset, offset + limit - 1)
              .count(CountOption.exact);
          return PageResult(
            items: res.data.map(_groupFromRow).toList(),
            total: res.count,
          );
        } on PostgrestException catch (e) {
          if (!_pastLastPage(e)) rethrow;
          return PageResult<ClosingDues>(items: const [], total: offset);
        }
      });

  @override
  Future<List<MemberDue>> fetchClosingDues(String closingCaseId) =>
      _guard(() async {
        final rows = await _db.rpc(
          'agent_closing_dues',
          params: {'p_closing_case_id': closingCaseId},
        ) as List;
        return rows
            .cast<Map<String, dynamic>>()
            .map(SupabaseTrustRepository.memberDueFromRow)
            .toList();
      });

  @override
  Future<List<MemberDue>> fetchMemberDues(String memberId) => _guard(() async {
        final rows = await _db.rpc(
          'agent_member_dues',
          params: {'p_member_id': memberId},
        ) as List;
        return rows
            .cast<Map<String, dynamic>>()
            .map(SupabaseTrustRepository.memberDueFromRow)
            .toList();
      });

  @override
  Future<void> reportClosing(ClosingRequest r) => _guard(() => _db.rpc(
        'agent_request_closing',
        params: {
          'p_request': {
            'member_id': r.memberId,
            'date_of_death': _dateFormat.format(r.eventDate),
            'nominee_name': r.nomineeName,
            'nominee_relation': r.nomineeRelation,
            'certificate_url': r.certificateUrl,
            'remarks': r.remarks,
          },
        },
      ));

  @override
  Future<List<ClosingRequest>> fetchMyClosingReports() => _guard(() async {
        final rows = await _db.rpc('agent_closing_requests') as List;
        return rows
            .cast<Map<String, dynamic>>()
            .map(SupabaseTrustRepository.closingRequestFromRow)
            .toList();
      });

  @override
  Future<List<OpenCashReceipt>> fetchOpenCash() => _guard(() async {
        final rows = await _db.rpc('agent_open_cash') as List;
        return rows
            .cast<Map<String, dynamic>>()
            .map(OpenCashReceipt.fromRow)
            .toList();
      });

  @override
  Future<double> declareHandover({
    List<String> paymentIds = const [],
    String note = '',
  }) =>
      _guard(() async {
        final result = await _db.rpc('agent_declare_handover', params: {
          // Null means every open receipt; the database decides which.
          'p_payment_ids': paymentIds.isEmpty ? null : paymentIds,
          'p_note': note,
        }) as Map<String, dynamic>;
        return (result['amount'] as num).toDouble();
      });

  @override
  Future<List<CashHandover>> fetchMyHandovers() => _guard(() async {
        final rows = await _db.rpc('agent_handovers') as List;
        return rows
            .cast<Map<String, dynamic>>()
            .map(CashHandover.fromRow)
            .toList();
      });

  @override
  Future<List<CommissionMonth>> fetchMyCommission({int months = 6}) =>
      _guard(() async {
        final rows =
            await _db.rpc('agent_commission', params: {'p_months': months})
                as List;
        return rows
            .cast<Map<String, dynamic>>()
            .map(CommissionMonth.fromRow)
            .toList();
      });

  static ClosingDues _groupFromRow(Map<String, dynamic> r) =>
      ClosingDues(
        yojnaId: r['yojna_id'] as String,
        yojnaName: r['yojna_name'] as String? ?? '',
        closingGroup: r['closing_group'] as String,
        closingDate: _date(r['closing_date']),
        closingCaseId: r['closing_case_id'] as String,
        beneficiaryName: r['beneficiary_name'] as String? ?? '',
        memberCount: (r['member_count'] as num).toInt(),
        paidCount: (r['paid_count'] as num).toInt(),
        pendingCount: (r['pending_count'] as num).toInt(),
        dueCount: (r['due_count'] as num).toInt(),
        toCollect: (r['to_collect'] as num).toDouble(),
      );

  static DateTime _date(Object? v) =>
      v is String ? DateTime.parse(v).toLocal() : DateTime.now();

  static DateTime? _timestamp(Object? v) =>
      v is String ? DateTime.parse(v).toLocal() : null;

  static Member _memberFromRow(Map<String, dynamic> r) => Member(
        id: r['id'] as String,
        yojnaId: r['yojna_id'] as String,
        regNo: r['reg_no'] as String? ?? '',
        name: r['name'] as String,
        fatherOrHusbandName: r['father_or_husband_name'] as String? ?? '',
        jati: r['jati'] as String? ?? '',
        gotra: r['gotra'] as String? ?? '',
        dob: r['dob'] == null ? null : _date(r['dob']),
        warisName: r['waris_name'] as String? ?? '',
        warisRelation: r['waris_relation'] as String? ?? '',
        gender: Gender.fromName(r['gender'] as String?),
        primaryPhone: r['primary_phone'] as String? ?? '',
        altPhone: r['alt_phone'] as String? ?? '',
        // Agents never receive the Aadhaar number, only the last four digits.
        aadhaar: '',
        storedAadhaarLast4: r['aadhaar_last4'] as String? ?? '',
        village: r['village'] as String? ?? '',
        tehsil: r['tehsil'] as String? ?? '',
        district: r['district'] as String? ?? '',
        state: r['state'] as String? ?? '',
        pincode: r['pincode'] as String? ?? '',
        joinDate: _date(r['join_date']),
        status: MemberStatus.fromName(r['status'] as String?),
        closingDate:
            r['closing_date'] == null ? null : _date(r['closing_date']),
        closingGroup: r['closing_group'] as String?,
        reviewNote: r['review_note'] as String? ?? '',
        photoUrl: r['photo_url'] as String? ?? '',
        email: r['email'] as String? ?? '',
      );

  static Payment _paymentFromRow(Map<String, dynamic> r) => Payment(
        id: r['id'] as String,
        receiptNo: r['receipt_no'] as String,
        memberId: r['member_id'] as String,
        yojnaId: r['yojna_id'] as String,
        amount: (r['amount'] as num).toDouble(),
        date: _date(r['date']),
        mode: PaymentMode.fromName(r['mode'] as String?),
        status: PaymentStatus.fromName(r['status'] as String?),
        kind: PaymentKind.fromName(r['kind'] as String?),
        reference: r['reference'] as String? ?? '',
        note: r['note'] as String? ?? '',
        closingCaseId: r['closing_case_id'] as String?,
        closingGroup: r['closing_group'] as String? ?? '',
        source: PaymentSource.agent,
        rejectReason: r['reject_reason'] as String? ?? '',
        cancelledAt: _timestamp(r['cancelled_at']),
        cancelReason: r['cancel_reason'] as String? ?? '',
        cancelRequestedAt: _timestamp(r['cancel_requested_at']),
        cancelRequestReason: r['cancel_request_reason'] as String? ?? '',
      );
}

/// Demo mode and widget tests: works on the in-memory data as one agent
/// ([agentId], or the first active agent when that id is unknown).
class InMemoryAgentRepository implements AgentRepository {
  InMemoryAgentRepository(this._base, {this.agentId});

  final InMemoryTrustRepository _base;
  final String? agentId;

  Future<Agent> _me() async {
    final agents = await _base.fetchAgents();
    final mine = agents.where((a) => a.id == agentId);
    if (mine.isNotEmpty) return mine.first;
    final active = agents.where((a) => a.isActive);
    if (active.isNotEmpty) return active.first;
    // A demo build starts with no records at all.
    throw const RepositoryException(
      'No agent record yet. Add an agent from the admin screens first.',
    );
  }

  Future<List<Member>> _myMembers() async {
    final me = await _me();
    return (await _base.fetchMembers())
        .where((m) => m.agentId == me.id)
        .toList()
      ..sort((a, b) => b.joinDate.compareTo(a.joinDate));
  }

  Future<Member> _myMember(String id) async {
    final found = (await _myMembers()).where((m) => m.id == id);
    if (found.isEmpty) throw const RepositoryException('Member not found.');
    return found.first;
  }

  static PageResult<T> _slice<T>(List<T> all, int offset, int limit) =>
      PageResult(
        items: all.skip(offset).take(limit).toList(),
        total: all.length,
      );

  @override
  Future<AgentSummary> fetchSummary() async {
    final me = await _me();
    final members = await _myMembers();
    final payments = (await _base.fetchPayments())
        .where((p) => p.agentId == me.id && !p.isCancelled);
    final pending = payments.where((p) => p.status == PaymentStatus.pending);
    final now = DateTime.now();
    return AgentSummary(
      activeMembers:
          members.where((m) => m.status == MemberStatus.active).length,
      pendingMembers: members.where((m) => m.isPending).length,
      pendingPayments: pending.length,
      pendingAmount: pending.fold(0, (sum, p) => sum + p.amount),
      monthApproved: payments
          .where((p) =>
              p.status == PaymentStatus.paid &&
              !p.date.isBefore(DateTime(now.year, now.month)))
          .fold(0, (sum, p) => sum + p.amount),
      cashInHand: _base.cashInHandOf(me.id),
      handoverWaiting: _base.handoverWaitingOf(me.id),
      monthCommission:
          _base.commissionOf(me.id, DateTime(now.year, now.month)).amount,
    );
  }

  @override
  Future<List<Yojna>> fetchMyYojnas() async {
    final me = await _me();
    return (await _base.fetchYojnas())
        .where((y) =>
            y.isActive && (me.yojnaIds.isEmpty || me.yojnaIds.contains(y.id)))
        .toList();
  }

  @override
  Future<PageResult<Member>> fetchMyMembers({
    String text = '',
    MemberStatus? status,
    required int offset,
    required int limit,
  }) async {
    final q = text.trim().toLowerCase();
    final matches = (await _myMembers())
        .where((m) =>
            (status == null || m.status == status) &&
            (q.isEmpty || m.searchIndex.contains(q)))
        .map((m) => m.copyWith(aadhaar: ''))
        .toList();
    return _slice(matches, offset, limit);
  }

  @override
  Future<void> addMember(Member member) async {
    final me = await _me();
    if (!(await fetchMyYojnas()).any((y) => y.id == member.yojnaId)) {
      throw const RepositoryException('You cannot enrol members in this Yojna.');
    }
    await _base.createMember(
      member.copyWith(regNo: '', agentId: me.id, status: MemberStatus.pending),
    );
  }

  @override
  Future<void> updateContact(Member member) async {
    final existing = await _myMember(member.id);
    await _base.updateMember(
      existing.copyWith(
        primaryPhone: member.primaryPhone,
        altPhone: member.altPhone,
        village: member.village,
        tehsil: member.tehsil,
        district: member.district,
        state: member.state,
        pincode: member.pincode,
        email: member.email,
      ),
    );
  }

  @override
  Future<String> recordPayment(Payment payment) async {
    final me = await _me();
    final member = await _myMember(payment.memberId);
    if (payment.kind == PaymentKind.closingPayout) {
      throw const RepositoryException('Agents cannot record claim payouts.');
    }
    if (member.isClosed) {
      throw const RepositoryException('This membership is closed.');
    }
    if (member.status != MemberStatus.active &&
        payment.kind != PaymentKind.registration) {
      throw const RepositoryException(
        'Only the registration fee can be collected before the member is approved.',
      );
    }
    final closingId = payment.closingCaseId;
    if (closingId != null) {
      if (payment.kind != PaymentKind.contribution) {
        throw const RepositoryException(
          'Only a contribution can be for a closing.',
        );
      }
      final owed = (await fetchMemberDues(member.id))
          .where((d) => d.closingCaseId == closingId);
      if (owed.isEmpty) {
        throw const RepositoryException(
          'This member does not owe for that closing.',
        );
      }
      if (owed.first.toCollect <= 0) {
        throw const RepositoryException(
          "This member's contribution for that closing is already collected.",
        );
      }
    }
    final receiptNo = await _base.nextReceiptNo();
    await _base.createPayment(
      Payment(
        id: '',
        receiptNo: receiptNo,
        memberId: member.id,
        yojnaId: member.yojnaId,
        amount: payment.amount,
        date: payment.date,
        mode: payment.mode,
        kind: payment.kind,
        status: PaymentStatus.pending,
        agentId: me.id,
        reference: payment.reference,
        note: payment.note,
        closingCaseId: closingId,
        source: PaymentSource.agent,
      ),
    );
    return receiptNo;
  }

  @override
  Future<PaymentPage> fetchMyPayments({
    PaymentStatus? status,
    required int offset,
    required int limit,
  }) async {
    final me = await _me();
    final mine = (await _base.fetchPayments())
        .where((p) => p.agentId == me.id && (status == null || p.status == status))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final page = _slice(mine, offset, limit);
    final ids = page.items.map((p) => p.memberId).toSet();
    final groups = {
      for (final c in await _base.fetchClosingCases()) c.id: c.closingGroup,
    };
    return PaymentPage(
      items: [
        for (final p in page.items)
          p.closingCaseId == null
              ? p
              : p.copyWith(closingGroup: groups[p.closingCaseId] ?? ''),
      ],
      total: page.total,
      members: {
        for (final m in await _base.fetchMembers())
          if (ids.contains(m.id)) m.id: MemberRef.of(m),
      },
    );
  }

  @override
  Future<void> requestCancel(String paymentId, String reason) async {
    final me = await _me();
    if (reason.trim().isEmpty) {
      throw const RepositoryException('Give a reason for cancelling.');
    }
    final found = (await _base.fetchPayments()).where((p) =>
        p.id == paymentId &&
        p.agentId == me.id &&
        p.status != PaymentStatus.failed &&
        !p.isCancelled &&
        p.cancelRequestedAt == null);
    if (found.isEmpty) {
      throw const RepositoryException(
        'This receipt cannot be cancelled, or a request is already open.',
      );
    }
    await _base.updatePayment(
      found.first.copyWith(
        cancelRequestedAt: DateTime.now(),
        cancelRequestReason: reason.trim(),
      ),
    );
  }

  Future<List<MemberDue>> _myDues() async {
    final mine = {for (final m in await _myMembers()) m.id};
    return _base.allDues().where((d) => mine.contains(d.memberId)).toList();
  }

  @override
  Future<PageResult<ClosingDues>> fetchClosings({
    required int offset,
    required int limit,
  }) async {
    final yojnas = {for (final y in await _base.fetchYojnas()) y.id: y.name};
    final byClosing = <String, List<MemberDue>>{};
    for (final d in await _myDues()) {
      byClosing.putIfAbsent(d.closingCaseId, () => []).add(d);
    }
    final closings = [
      for (final dues in byClosing.values)
        ClosingDues.of(dues, yojnaName: yojnas[dues.first.yojnaId] ?? ''),
    ]..sort((a, b) => b.closingDate.compareTo(a.closingDate));
    return _slice(closings, offset, limit);
  }

  @override
  Future<List<MemberDue>> fetchClosingDues(String closingCaseId) async =>
      (await _myDues())
          .where((d) => d.closingCaseId == closingCaseId)
          .toList()
        ..sort((a, b) {
          final byState = a.state.index.compareTo(b.state.index);
          return byState != 0 ? byState : a.memberName.compareTo(b.memberName);
        });

  @override
  Future<List<MemberDue>> fetchMemberDues(String memberId) async {
    await _myMember(memberId);
    return _base.fetchMemberDues(memberId);
  }

  @override
  Future<void> reportClosing(ClosingRequest request) async {
    final me = await _me();
    final member = await _myMember(request.memberId);
    if (member.status != MemberStatus.active) {
      throw const RepositoryException(
        'Only an active member can be reported for a closing.',
      );
    }
    if (request.eventDate.isAfter(DateTime.now())) {
      throw const RepositoryException(
        'The event date cannot be in the future.',
      );
    }
    if (!request.certificateUrl.startsWith('https://res.cloudinary.com/')) {
      throw const RepositoryException('Upload the proof document.');
    }
    if (_base.allClosingRequests().any((r) =>
        r.memberId == member.id && r.status == RequestStatus.pending)) {
      throw const RepositoryException(
        'A report for this member is already waiting for the office.',
      );
    }
    if ((await _base.fetchClosingCases()).any((c) => c.memberId == member.id)) {
      throw const RepositoryException('This member already has a closing.');
    }
    await _base.createClosingRequest(request.copyWith(agentId: me.id));
  }

  @override
  Future<List<ClosingRequest>> fetchMyClosingReports() async {
    final me = await _me();
    return _base.allClosingRequests().where((r) => r.agentId == me.id).toList();
  }

  // ---- Cash and commission (IMPLEMENTATION_PLAN Phase 16) ------------------

  @override
  Future<List<OpenCashReceipt>> fetchOpenCash() async {
    final me = await _me();
    final members = {for (final m in await _base.fetchMembers()) m.id: m};
    return [
      for (final p in _base.openCashOf(me.id))
        OpenCashReceipt(
          id: p.id,
          receiptNo: p.receiptNo,
          memberName: members[p.memberId]?.name ?? '',
          memberRegNo: members[p.memberId]?.regNo ?? '',
          amount: p.amount,
          date: p.date,
        ),
    ];
  }

  @override
  Future<double> declareHandover({
    List<String> paymentIds = const [],
    String note = '',
  }) async {
    final me = await _me();
    return _base.declareHandover(me.id, paymentIds: paymentIds, note: note);
  }

  @override
  Future<List<CashHandover>> fetchMyHandovers() async {
    final me = await _me();
    return _base.handoversOf(me.id);
  }

  @override
  Future<List<CommissionMonth>> fetchMyCommission({int months = 6}) async {
    final me = await _me();
    final now = DateTime.now();
    return [
      for (var i = 0; i < months; i++)
        _base.commissionOf(me.id, DateTime(now.year, now.month - i)),
    ];
  }
}

