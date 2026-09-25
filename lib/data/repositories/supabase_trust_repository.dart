import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'trust_repository.dart';

/// [TrustRepository] backed by Supabase (Postgres + row-level security).
///
/// Registration numbers, receipt numbers and agent codes are assigned by
/// database triggers, so the `next*` methods only return a preview for the
/// form. Schema: `supabase/migrations/`.
class SupabaseTrustRepository implements TrustRepository {
  SupabaseTrustRepository(this._db);

  final SupabaseClient _db;

  /// PostgREST caps each response at 1,000 rows (`max_rows`).
  static const _pageSize = 1000;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  // ---- Yojna -------------------------------------------------------------

  @override
  Future<List<Yojna>> fetchYojnas() => _guard(() async {
        final rows = await _fetchAll('yojnas', orderBy: 'created_at', ascending: true);
        return rows.map(_yojnaFromRow).toList();
      });

  @override
  Future<Yojna> createYojna(Yojna yojna) => _guard(() async {
        final row = await _db.from('yojnas').insert(_yojnaToRow(yojna)).select().single();
        return _yojnaFromRow(row);
      });

  @override
  Future<Yojna> updateYojna(Yojna yojna) => _guard(() async {
        final row = await _db
            .from('yojnas')
            .update(_yojnaToRow(yojna))
            .eq('id', yojna.id)
            .select()
            .single();
        return _yojnaFromRow(row);
      });

  @override
  Future<void> deleteYojna(String id) =>
      _guard(() => _db.from('yojnas').delete().eq('id', id));

  // ---- Members -----------------------------------------------------------

  @override
  Future<PageResult<Member>> fetchMembersPage(
    MemberQuery query, {
    required int offset,
    required int limit,
  }) =>
      _guard(() async {
        final params = _memberParams(query);
        try {
          final res = await _db
              .rpc('search_members', params: params)
              .select()
              .order('join_date', ascending: false)
              .order('reg_no', ascending: false)
              .range(offset, offset + limit - 1)
              .count(CountOption.exact);
          return PageResult(
            items: res.data.map(_memberFromRow).toList(),
            total: res.count,
          );
        } on PostgrestException catch (e) {
          if (!_isPastLastPage(e)) rethrow;
          return PageResult<Member>(
            items: const [],
            total: await _countRpc('search_members', params),
          );
        }
      });

  @override
  Future<List<Member>> fetchMembersByIds(Iterable<String> ids) =>
      _guard(() async {
        final all = ids.toSet().toList();
        final members = <Member>[];
        // Keep each request URL well under proxy limits.
        for (var i = 0; i < all.length; i += 100) {
          final chunk = all.sublist(i, (i + 100).clamp(0, all.length));
          final rows = await _db.from('members').select().inFilter('id', chunk);
          members.addAll(rows.map(_memberFromRow));
        }
        return members;
      });

  @override
  Future<List<Member>> searchMembers(
    String text, {
    int limit = 20,
    bool excludeClosed = false,
  }) =>
      _guard(() async {
        var request = _db.rpc('search_members', params: {'p_query': text.trim()});
        if (excludeClosed) request = request.neq('status', 'closed');
        final rows = await request
            .select()
            .order('join_date', ascending: false)
            .limit(limit);
        return rows.map(_memberFromRow).toList();
      });

  @override
  Future<List<String>> fetchMemberDistricts() => _guard(() async {
        final rows = await _db.rpc('member_districts') as List;
        return rows
            .map((r) => r is Map ? r.values.first as String : r as String)
            .toList();
      });

  @override
  Future<Member> createMember(Member member) => _guard(() async {
        final row = await _db
            .from('members')
            .insert({..._memberToRow(member), 'reg_no': ''})
            .select()
            .single();
        return _memberFromRow(row);
      });

  @override
  Future<Member> updateMember(Member member) => _guard(() async {
        final row = await _db
            .from('members')
            .update(_memberToRow(member))
            .eq('id', member.id)
            .select()
            .single();
        return _memberFromRow(row);
      });

  @override
  Future<void> deleteMember(String id) =>
      _guard(() => _db.from('members').delete().eq('id', id));

  @override
  Future<Member?> findMemberByPhone(String phone) => _guard(() async {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.length != 10) return null;
        final row = await _db
            .from('members')
            .select()
            .or('primary_phone.eq.$digits,alt_phone.eq.$digits')
            .order('join_date', ascending: false)
            .limit(1)
            .maybeSingle();
        return row == null ? null : _memberFromRow(row);
      });

  @override
  Future<String> nextRegNo(String yojnaId) => _guard(() async {
        final yojna =
            await _db.from('yojnas').select('code').eq('id', yojnaId).single();
        final prefix = '${yojna['code']}-${_istNow().year}';
        final next = await _peekCounter(prefix) + 1;
        return '$prefix-${next.toString().padLeft(4, '0')}';
      });

  // ---- Agents ------------------------------------------------------------

  @override
  Future<List<Agent>> fetchAgents() => _guard(() async {
        final rows = await _fetchAll('agents', orderBy: 'code', ascending: true);
        return rows.map(_agentFromRow).toList();
      });

  @override
  Future<Agent> createAgent(Agent agent) => _guard(() async {
        final row = await _db
            .from('agents')
            .insert({..._agentToRow(agent), 'code': ''})
            .select()
            .single();
        return _agentFromRow(row);
      });

  @override
  Future<Agent> updateAgent(Agent agent) => _guard(() async {
        final row = await _db
            .from('agents')
            .update(_agentToRow(agent))
            .eq('id', agent.id)
            .select()
            .single();
        return _agentFromRow(row);
      });

  @override
  Future<void> deleteAgent(String id) =>
      _guard(() => _db.from('agents').delete().eq('id', id));

  @override
  Future<String> nextAgentCode() => _guard(() async {
        final next = await _peekCounter('AG') + 1;
        return 'AG-${next.toString().padLeft(3, '0')}';
      });

  // ---- Payments ----------------------------------------------------------

  @override
  Future<PaymentPage> fetchPaymentsPage(
    PaymentQuery query, {
    required int offset,
    required int limit,
  }) =>
      _guard(() async {
        final params = _paymentParams(query);
        try {
          final res = await _db
              .rpc('search_payments', params: params)
              .select(_withMember)
              .order('date', ascending: false)
              .order('receipt_no', ascending: false)
              .range(offset, offset + limit - 1)
              .count(CountOption.exact);

          return _paymentPage(res.data, res.count);
        } on PostgrestException catch (e) {
          if (!_isPastLastPage(e)) rethrow;
          return PaymentPage(
            items: const [],
            total: await _countRpc('search_payments', params),
          );
        }
      });

  static const _withMember = '*, member:members(id, name, reg_no, primary_phone)';

  /// Payments whose rows embed `member` (see [_withMember]).
  static PaymentPage _paymentPage(List<Map<String, dynamic>> rows, int total) {
    final members = <String, MemberRef>{};
    for (final row in rows) {
      final m = row['member'];
      if (m is Map<String, dynamic>) {
        members[m['id'] as String] = MemberRef(
          id: m['id'] as String,
          name: m['name'] as String? ?? '',
          regNo: m['reg_no'] as String? ?? '',
          primaryPhone: m['primary_phone'] as String? ?? '',
        );
      }
    }
    return PaymentPage(
      items: rows.map(_paymentFromRow).toList(),
      total: total,
      members: members,
    );
  }

  @override
  Future<PaymentTotals> fetchPaymentTotals(PaymentQuery query) =>
      _guard(() async {
        final row = await _firstRow('payment_totals', _paymentParams(query));
        if (row == null) return PaymentTotals.empty;
        return PaymentTotals(
          count: (row['count'] as num?)?.toInt() ?? 0,
          paid: _num(row['paid']),
          pending: _num(row['pending']),
          failed: _num(row['failed']),
        );
      });

  @override
  Future<Payment> createPayment(Payment payment) => _guard(() async {
        final row = await _db
            .from('payments')
            .insert({..._paymentToRow(payment), 'receipt_no': ''})
            .select()
            .single();
        return _paymentFromRow(row);
      });

  @override
  Future<Payment> updatePayment(Payment payment) => _guard(() async {
        final row = await _db
            .from('payments')
            .update(_paymentToRow(payment))
            .eq('id', payment.id)
            .select()
            .single();
        return _paymentFromRow(row);
      });

  @override
  Future<void> deletePayment(String id) =>
      _guard(() => _db.from('payments').delete().eq('id', id));

  @override
  Future<String> nextReceiptNo() => _guard(() async {
        final next = await _peekCounter('RCP') + 1;
        return 'RCP-${1000 + next}';
      });

  // ---- Closing cases -----------------------------------------------------

  @override
  Future<List<ClosingCase>> fetchClosingCases() => _guard(() async {
        final rows = await _fetchAll('closing_cases', orderBy: 'closing_date');
        return rows.map(_closingFromRow).toList();
      });

  @override
  Future<ClosingCase> createClosingCase(ClosingCase value) => _guard(() async {
        final row = await _db
            .from('closing_cases')
            .insert(_closingToRow(value))
            .select()
            .single();
        return _closingFromRow(row);
      });

  @override
  Future<ClosingCase> updateClosingCase(ClosingCase value) => _guard(() async {
        final row = await _db
            .from('closing_cases')
            .update(_closingToRow(value))
            .eq('id', value.id)
            .select()
            .single();
        return _closingFromRow(row);
      });

  @override
  Future<void> deleteClosingCase(String id) =>
      _guard(() => _db.from('closing_cases').delete().eq('id', id));

  // ---- Aggregates --------------------------------------------------------

  @override
  Future<DashboardStats> fetchDashboardStats(String? yojnaId) =>
      _guard(() async {
        final row = await _firstRow('dashboard_stats', {'p_yojna_id': yojnaId});
        if (row == null) return DashboardStats.empty;
        int count(String key) => (row[key] as num?)?.toInt() ?? 0;
        return DashboardStats(
          totalMembers: count('total_members'),
          activeMembers: count('active_members'),
          inactiveMembers: count('inactive_members'),
          closedMembers: count('closed_members'),
          totalAgents: count('total_agents'),
          activeAgents: count('active_agents'),
          monthCollection: _num(row['month_collection']),
          previousMonthCollection: _num(row['previous_month_collection']),
          pendingClaims: _num(row['pending_claims']),
        );
      });

  @override
  Future<Map<String, int>> fetchMembersPerYojna() => _guard(() async {
        final rows = await _db.rpc('members_per_yojna') as List;
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['yojna_id'] as String: (r['member_count'] as num).toInt(),
        };
      });

  @override
  Future<Map<String, int>> fetchMemberCountByAgent() => _guard(() async {
        final rows = await _db.rpc('member_count_by_agent') as List;
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['agent_id'] as String: (r['member_count'] as num).toInt(),
        };
      });

  @override
  Future<Map<String, double>> fetchCollectionByAgent() => _guard(() async {
        final rows = await _db.rpc('collection_by_agent') as List;
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['agent_id'] as String: _num(r['total']),
        };
      });

  // ---- Approvals -----------------------------------------------------------

  /// The approval queue is small; one request is enough.
  static const _queueLimit = 500;

  @override
  Future<List<Member>> fetchPendingMembers() => _guard(() async {
        final rows = await _db
            .from('members')
            .select()
            .eq('status', 'pending')
            .order('created_at')
            .limit(_queueLimit);
        return rows.map(_memberFromRow).toList();
      });

  @override
  Future<PaymentPage> fetchPendingPayments() => _guard(() async {
        final rows = await _db
            .from('payments')
            .select(_withMember)
            .eq('status', 'pending')
            // Office-entered pending payments are unpaid dues, not submissions.
            .neq('source', 'admin')
            .isFilter('cancelled_at', null)
            .order('created_at')
            .limit(_queueLimit);
        return _paymentPage(rows, rows.length);
      });

  @override
  Future<PaymentPage> fetchCancelRequests() => _guard(() async {
        final rows = await _db
            .from('payments')
            .select(_withMember)
            .not('cancel_requested_at', 'is', null)
            .isFilter('cancelled_at', null)
            .order('cancel_requested_at')
            .limit(_queueLimit);
        return _paymentPage(rows, rows.length);
      });

  @override
  Future<String> approveMember(String memberId) => _guard(() async {
        final regNo = await _db
            .rpc('approve_member', params: {'p_member_id': memberId});
        return regNo as String? ?? '';
      });

  @override
  Future<void> rejectMember(String memberId, String reason) => _guard(
        () => _db.rpc('reject_member',
            params: {'p_member_id': memberId, 'p_reason': reason}),
      );

  @override
  Future<void> approvePayment(String paymentId) => _guard(
        () => _db.rpc('approve_payment', params: {'p_payment_id': paymentId}),
      );

  @override
  Future<void> rejectPayment(String paymentId, String reason) => _guard(
        () => _db.rpc('reject_payment',
            params: {'p_payment_id': paymentId, 'p_reason': reason}),
      );

  @override
  Future<void> cancelPayment(String paymentId, String reason) => _guard(
        () => _db.rpc('cancel_payment',
            params: {'p_payment_id': paymentId, 'p_reason': reason}),
      );

  @override
  Future<void> declineCancelRequest(String paymentId) => _guard(
        () => _db.rpc('decline_cancel_request',
            params: {'p_payment_id': paymentId}),
      );

  @override
  Future<int> reassignMembers(String fromAgentId, String toAgentId) =>
      _guard(() async {
        final moved = await _db.rpc('reassign_members', params: {
          'p_from_agent': fromAgentId,
          'p_to_agent': toAgentId,
        });
        return (moved as num?)?.toInt() ?? 0;
      });

  // ---- Dues and closing reports ------------------------------------------------

  @override
  Future<List<MemberDue>> fetchMemberDues(String memberId) =>
      _guard(() async {
        final rows = await _db
            .from('member_dues')
            .select()
            .eq('member_id', memberId)
            .order('closing_date');
        return rows.map(memberDueFromRow).toList();
      });

  @override
  Future<PageResult<MemberDuesSummary>> fetchDuesPage(
    DuesQuery query, {
    required int offset,
    required int limit,
  }) =>
      _guard(() async {
        final params = _duesParams(query);
        try {
          final res = await _db
              .rpc('office_member_dues', params: params)
              .select()
              .order('due', ascending: false)
              .order('name')
              .order('reg_no')
              .range(offset, offset + limit - 1)
              .count(CountOption.exact);
          return PageResult(
            items: res.data.map(_duesSummaryFromRow).toList(),
            total: res.count,
          );
        } on PostgrestException catch (e) {
          if (!_isPastLastPage(e)) rethrow;
          return PageResult<MemberDuesSummary>(
            items: const [],
            total: await _countRpc('office_member_dues', params),
          );
        }
      });

  @override
  Future<DuesTotals> fetchDuesTotals(DuesQuery query) => _guard(() async {
        final params = _duesParams(query)..remove('p_owing');
        final row = await _firstRow('office_dues_totals', params);
        if (row == null) return DuesTotals.empty;
        return DuesTotals(
          memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
          owingCount: (row['owing_count'] as num?)?.toInt() ?? 0,
          due: _num(row['due']),
          pending: _num(row['pending']),
          contributed: _num(row['contributed']),
        );
      });

  static MemberDuesSummary _duesSummaryFromRow(Map<String, dynamic> r) =>
      MemberDuesSummary(
        memberId: r['id'] as String,
        yojnaId: r['yojna_id'] as String,
        regNo: r['reg_no'] as String? ?? '',
        name: r['name'] as String? ?? '',
        joinDate: _parseDate(r['join_date']),
        phone: r['primary_phone'] as String? ?? '',
        village: r['village'] as String? ?? '',
        agentId: r['agent_id'] as String?,
        status: MemberStatus.fromName(r['status'] as String?),
        closingsOwed: (r['closings_owed'] as num?)?.toInt() ?? 0,
        due: _num(r['due']),
        pending: _num(r['pending']),
        contributed: _num(r['contributed']),
        lastContribution: r['last_contribution'] == null
            ? null
            : _parseDate(r['last_contribution']),
      );

  @override
  Future<List<ClosingRequest>> fetchPendingClosingRequests() =>
      _guard(() async {
        final rows = await _db
            .from('closing_requests')
            .select('*, member:members(name, reg_no, yojna_id)')
            .eq('status', 'pending')
            .order('created_at');
        return rows.map(closingRequestFromRow).toList();
      });

  @override
  Future<String> approveClosingRequest(
    String requestId, {
    required String closingGroup,
    double? claimAmount,
  }) =>
      _guard(() async {
        final id = await _db.rpc('approve_closing_request', params: {
          'p_request_id': requestId,
          'p_closing_group': closingGroup,
          'p_claim_amount': claimAmount,
        });
        return id as String;
      });

  @override
  Future<void> rejectClosingRequest(String requestId, String reason) =>
      _guard(() => _db.rpc('reject_closing_request', params: {
            'p_request_id': requestId,
            'p_reason': reason,
          }));

  // ---- Notifications and announcements (IMPLEMENTATION_PLAN Phase 14) -------

  @override
  Future<List<AppNotification>> fetchNotifications({int limit = 30}) =>
      _guard(() async {
        final rows = await _db.rpc(
          'my_notifications',
          params: {'p_limit': limit, 'p_offset': 0},
        ) as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            AppNotification.fromRow(r),
        ];
      });

  @override
  Future<int> fetchUnreadCount() =>
      _guard(() async => (await _db.rpc('my_unread_count') as num).toInt());

  @override
  Future<void> markNotificationRead(int id) => _guard(
        () => _db.rpc('mark_notification_read', params: {'p_id': id}),
      );

  @override
  Future<int> markAllNotificationsRead() => _guard(
        () async =>
            (await _db.rpc('mark_all_notifications_read') as num).toInt(),
      );

  @override
  Future<List<Announcement>> fetchAnnouncements({int limit = 20}) =>
      _guard(() async {
        final rows = await _db.rpc(
          'my_announcements',
          params: {'p_limit': limit, 'p_offset': 0},
        ) as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            Announcement.fromRow(r),
        ];
      });

  @override
  Future<String> postAnnouncement({
    required String title,
    String body = '',
    String? yojnaId,
  }) =>
      _guard(() async => await _db.rpc('post_announcement', params: {
            'p_title': title,
            'p_body': body,
            'p_yojna_id': yojnaId,
          }) as String);

  @override
  Future<void> deleteAnnouncement(String id) => _guard(
        () => _db.rpc('delete_announcement', params: {'p_id': id}),
      );

  // ---- Member portal (IMPLEMENTATION_PLAN Phase 15) -------------------------

  @override
  Future<Membership> fetchMyMembership() => _guard(() async {
        final rows = await _db.rpc('my_membership') as List;
        if (rows.isEmpty) {
          throw const RepositoryException('Only a member can do this.');
        }
        return Membership.fromRow(rows.first as Map<String, dynamic>);
      });

  @override
  Future<List<Payment>> fetchMyPayments({int limit = 50}) => _guard(() async {
        final rows = await _db.rpc(
          'my_member_payments',
          params: {'p_limit': limit, 'p_offset': 0},
        ) as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            // The portal returns a receipt, not the whole payment row: the
            // member and Yojna are already known from the membership.
            Payment(
              id: r['id'] as String,
              receiptNo: r['receipt_no'] as String? ?? '',
              memberId: '',
              yojnaId: '',
              amount: _num(r['amount']),
              date: _parseDate(r['date']),
              mode: PaymentMode.fromName(r['mode'] as String?),
              status: PaymentStatus.fromName(r['status'] as String?),
              kind: PaymentKind.fromName(r['kind'] as String?),
              reference: r['reference'] as String? ?? '',
              rejectReason: r['reject_reason'] as String? ?? '',
              cancelledAt: _parseTimestamp(r['cancelled_at']),
            ),
        ];
      });

  @override
  Future<List<MemberDue>> fetchMyDues() => _guard(() async {
        final rows = await _db.rpc('my_member_dues') as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            memberDueFromRow({...r, 'member_id': ''}),
        ];
      });

  @override
  Future<ClosingCase?> fetchMyClosingCase() => _guard(() async {
        final rows = await _db.rpc('my_closing_case') as List;
        if (rows.isEmpty) return null;
        final r = rows.first as Map<String, dynamic>;
        return ClosingCase(
          id: '',
          memberId: '',
          yojnaId: '',
          closingDate: _parseDate(r['closing_date']),
          closingGroup: r['closing_group'] as String? ?? '',
          claimAmount: _num(r['claim_amount']),
          collectedAmount: _num(r['collected_amount']),
          payStatus: ClosingPayStatus.fromName(r['pay_status'] as String?),
          nomineeName: r['nominee_name'] as String? ?? '',
        );
      });

  @override
  Future<String> submitUpiPayment({
    required double amount,
    required String reference,
    String? closingCaseId,
  }) =>
      _guard(() async => await _db.rpc('member_submit_upi', params: {
            'p_amount': amount,
            'p_reference': reference,
            'p_closing_case_id': closingCaseId,
          }) as String);

  @override
  Future<OnlineOrder> startOnlinePayment(String closingCaseId) async {
    final data = await _invoke('razorpay_order', {
      'closing_case_id': closingCaseId,
    });
    return OnlineOrder.fromJson(data);
  }

  @override
  Future<String> confirmOnlinePayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final data = await _invoke('razorpay_verify', {
      'order_id': orderId,
      'payment_id': paymentId,
      'signature': signature,
    });
    return (data['receipt_no'] ?? '') as String;
  }

  /// Calls an Edge Function, turning its `{ error }` into a readable
  /// [RepositoryException].
  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _db.functions.invoke(name, body: body);
      final data = res.data;
      if (data is! Map) {
        throw const RepositoryException('Something went wrong. Try again.');
      }
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw RepositoryException(
        message ?? 'Something went wrong (${e.status}). Try again.',
      );
    }
  }

  @override
  Future<String> requestChange(ChangeField field, String newValue) =>
      _guard(() async => await _db.rpc('request_change', params: {
            'p_field': field.column,
            'p_new_value': newValue,
          }) as String);

  @override
  Future<List<ChangeRequest>> fetchMyChangeRequests() => _guard(() async {
        final rows = await _db.rpc('my_change_requests') as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            ChangeRequest.fromRow(r),
        ];
      });

  @override
  Future<List<ChangeRequest>> fetchPendingChangeRequests() => _guard(() async {
        final rows = await _db.rpc('pending_change_requests') as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            ChangeRequest.fromRow(r),
        ];
      });

  @override
  Future<void> approveChangeRequest(String id) => _guard(
        () => _db.rpc('approve_change_request', params: {'p_id': id}),
      );

  @override
  Future<void> rejectChangeRequest(String id, String reason) => _guard(
        () => _db.rpc('reject_change_request', params: {
          'p_id': id,
          'p_reason': reason,
        }),
      );

  // ---- Cash handovers and commission (IMPLEMENTATION_PLAN Phase 16) --------

  @override
  Future<List<CashHandover>> fetchPendingHandovers() => _guard(() async {
        final rows = await _db.rpc('pending_handovers') as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            CashHandover.fromRow(r),
        ];
      });

  @override
  Future<void> confirmHandover(String id) => _guard(
        () => _db.rpc('confirm_handover', params: {'p_id': id}),
      );

  @override
  Future<void> rejectHandover(String id, String reason) => _guard(
        () => _db.rpc('reject_handover', params: {
          'p_id': id,
          'p_reason': reason,
        }),
      );

  @override
  Future<List<CommissionMonth>> fetchCommissionReport(DateTime month) =>
      _guard(() async {
        final first = DateTime(month.year, month.month);
        final rows = await _db.rpc('commission_report', params: {
          'p_month': _date(first),
        }) as List;
        return [
          for (final r in rows.cast<Map<String, dynamic>>())
            // The report is for one month, which the rows do not repeat.
            CommissionMonth.fromRow(r, month: first),
        ];
      });

  @override
  Future<Map<String, dynamic>> exportMemberData(String memberId) =>
      _guard(() async {
        final value = await _db.rpc(
          'export_member_data',
          params: {'p_member_id': memberId},
        );
        return Map<String, dynamic>.from(value as Map);
      });

  @override
  Future<void> eraseMemberData(String memberId, String reason) => _guard(
        () => _db.rpc('erase_member_data', params: {
          'p_member_id': memberId,
          'p_reason': reason,
        }),
      );

  @override
  Future<String> fetchMemberAadhaar(String memberId) => _guard(() async {
        final value = await _db.rpc(
          'member_aadhaar',
          params: {'p_member_id': memberId},
        );
        return (value as String?) ?? '';
      });

  @override
  Future<void> markCommissionPaid({
    required String agentId,
    required DateTime month,
    double? amount,
    String reference = '',
  }) =>
      _guard(
        () => _db.rpc('mark_commission_paid', params: {
          'p_agent_id': agentId,
          'p_month': _date(DateTime(month.year, month.month)),
          'p_amount': amount,
          'p_reference': reference,
        }),
      );

  /// A `member_dues` row, or an `agent_closing_dues` row with member details.
  static MemberDue memberDueFromRow(Map<String, dynamic> r) => MemberDue(
        memberId: r['member_id'] as String,
        yojnaId: r['yojna_id'] as String? ?? '',
        closingCaseId: r['closing_case_id'] as String,
        closingGroup: r['closing_group'] as String? ?? '',
        closingDate: _parseDate(r['closing_date']),
        amount: _num(r['amount']),
        paid: _num(r['paid']),
        pending: _num(r['pending']),
        beneficiaryName: r['beneficiary_name'] as String? ?? '',
        memberName: r['name'] as String? ?? '',
        regNo: r['reg_no'] as String? ?? '',
        phone: r['primary_phone'] as String? ?? '',
        village: r['village'] as String? ?? '',
      );

  /// A `closing_requests` row (member embedded as `member`), or an
  /// `agent_closing_requests` row.
  static ClosingRequest closingRequestFromRow(Map<String, dynamic> r) {
    final member = r['member'] as Map<String, dynamic>?;
    return ClosingRequest(
      id: r['id'] as String,
      memberId: r['member_id'] as String,
      memberName: member?['name'] as String? ?? r['member_name'] as String? ?? '',
      memberRegNo:
          member?['reg_no'] as String? ?? r['member_reg_no'] as String? ?? '',
      yojnaId: member?['yojna_id'] as String? ?? '',
      agentId: r['agent_id'] as String?,
      eventDate: _parseDate(r['date_of_death']),
      nomineeName: r['nominee_name'] as String? ?? '',
      nomineeRelation: r['nominee_relation'] as String? ?? '',
      certificateUrl: r['certificate_url'] as String? ?? '',
      remarks: r['remarks'] as String? ?? '',
      status: RequestStatus.fromName(r['status'] as String?),
      decisionNote: r['decision_note'] as String? ?? '',
      closingCaseId: r['closing_case_id'] as String?,
      createdAt: _parseTimestamp(r['created_at']),
    );
  }

  // ---- Helpers -----------------------------------------------------------

  static Map<String, dynamic> _memberParams(MemberQuery q) => {
        'p_yojna_id': q.yojnaId,
        'p_query': q.text.trim(),
        'p_status': q.status?.name,
        'p_agent_id': q.agentId,
        'p_district': q.district,
      };

  static Map<String, dynamic> _duesParams(DuesQuery q) => {
        'p_yojna_id': q.yojnaId,
        'p_query': q.text.trim(),
        'p_agent_id': q.agentId,
        'p_owing': switch (q.standing) {
          null => null,
          DuesStanding.owing => true,
          DuesStanding.clear => false,
        },
      };

  static Map<String, dynamic> _paymentParams(PaymentQuery q) => {
        'p_yojna_id': q.yojnaId,
        'p_member_id': q.memberId,
        'p_query': q.text.trim(),
        'p_mode': q.mode?.name,
        'p_status': q.status?.name,
        'p_kind': q.kind?.name,
        'p_from': q.from == null ? null : _date(q.from!),
        'p_to': q.to == null ? null : _date(q.to!),
      };

  /// PostgREST answers 416 when a range starts past the last row, e.g. after
  /// deleting the only row on the last page.
  static bool _isPastLastPage(PostgrestException e) =>
      e.code == 'PGRST103' || e.code == '416';

  Future<int> _countRpc(String fn, Map<String, dynamic> params) async {
    final res = await _db
        .rpc(fn, params: params)
        .select('id')
        .limit(1)
        .count(CountOption.exact);
    return res.count;
  }

  /// First row of a table-returning SQL function.
  Future<Map<String, dynamic>?> _firstRow(
    String fn,
    Map<String, dynamic> params,
  ) async {
    final rows = await _db.rpc(fn, params: params) as List;
    return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
  }

  /// Reads a whole table page by page, so nothing past row 1,000 is dropped.
  Future<List<Map<String, dynamic>>> _fetchAll(
    String table, {
    required String orderBy,
    bool ascending = false,
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final page = await _db
          .from(table)
          .select()
          .order(orderBy, ascending: ascending)
          .order('id')
          .range(from, from + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) return rows;
    }
  }

  /// Current value of a numbering counter, 0 when unused.
  Future<int> _peekCounter(String key) async {
    final row =
        await _db.from('counters').select('value').eq('key', key).maybeSingle();
    return (row?['value'] as num?)?.toInt() ?? 0;
  }

  /// Numbering in the database follows the Indian calendar year.
  static DateTime _istNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw RepositoryException(describePostgrestError(e));
    } on AuthException catch (_) {
      throw const RepositoryException(_sessionExpired);
    } on RepositoryException {
      rethrow;
    } catch (e) {
      final text = '$e';
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed to fetch')) {
        throw const RepositoryException(
          'Network error. Check your internet connection and try again.',
        );
      }
      rethrow;
    }
  }

  static const _sessionExpired =
      'Your session has expired. Please sign in again.';

  /// Turns a database error into a message an admin can act on.
  static String describePostgrestError(PostgrestException e) {
    final text = '${e.message} ${e.details ?? ''}';
    switch (e.code) {
      case '23505': // unique_violation
        if (text.contains('members_reg_no_key')) {
          return 'This registration number already exists.';
        }
        if (text.contains('payments_receipt_no_key')) {
          return 'This receipt number already exists.';
        }
        if (text.contains('yojnas_code_key')) {
          return 'This Yojna code already exists.';
        }
        if (text.contains('agents_code_key')) {
          return 'This agent code already exists.';
        }
        if (text.contains('closing_cases_member_id_key')) {
          return 'A closing case already exists for this member.';
        }
        return 'This record already exists.';
      case '23503': // foreign_key_violation
        if (text.contains('payments_member_id_fkey')) {
          return 'This member has receipts, so they cannot be deleted. '
              'Mark the member Inactive instead.';
        }
        if (text.contains('members_yojna_id_fkey') ||
            text.contains('payments_yojna_id_fkey') ||
            text.contains('closing_cases_yojna_id_fkey')) {
          return 'This Yojna has members or payments, so it cannot be deleted.';
        }
        return 'A linked record was not found. Refresh the page and try again.';
      case '23514': // check_violation
        if (text.contains('phone')) return 'Phone number must be 10 digits.';
        if (text.contains('pincode')) return 'PIN code must be 6 digits.';
        if (text.contains('aadhaar')) return 'Aadhaar number must be 12 digits.';
        if (text.contains('yojnas_code')) {
          return 'Yojna code must be 2–6 capital letters.';
        }
        if (text.contains('amount')) return 'Amount must be greater than zero.';
        if (text.contains('commission')) return 'Commission must be between 0 and 100%.';
        return 'Some of the details entered are not valid.';
      case '23502': // not_null_violation
        return 'Please fill in all required fields.';
      case 'P0001': // raise exception in our SQL functions: already readable
        return e.message;
      case '42501': // insufficient_privilege / RLS
        return 'You do not have permission to do this.';
      case 'PGRST116': // .single() found no row (deleted, or hidden by RLS)
        return 'Record not found. Refresh the page and try again.';
      case 'PGRST301':
      case 'PGRST303':
        return _sessionExpired;
    }
    return 'Server error: ${e.message}';
  }

  static String _date(DateTime d) => _dateFormat.format(d);

  static DateTime _parseDate(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : DateTime.now();

  static DateTime? _parseTimestamp(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;

  static double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

  /// Drops an empty client-side id so the database generates one.
  static Map<String, dynamic> _withId(String id, Map<String, dynamic> row) =>
      id.isEmpty ? row : {'id': id, ...row};

  // ---- Row mapping (snake_case columns ↔ camelCase models) ----------------

  static Map<String, dynamic> _yojnaToRow(Yojna y) => _withId(y.id, {
        'name': y.name,
        'code': y.code,
        'description': y.description,
        'contribution_amount': y.contributionAmount,
        'claim_amount': y.claimAmount,
        'registration_fee': y.registrationFee,
        'start_date': y.startDate == null ? null : _date(y.startDate!),
        'is_active': y.isActive,
      });

  static Yojna _yojnaFromRow(Map<String, dynamic> r) => Yojna(
        id: r['id'] as String,
        name: r['name'] as String,
        code: r['code'] as String,
        description: r['description'] as String? ?? '',
        contributionAmount: _num(r['contribution_amount']),
        claimAmount: _num(r['claim_amount']),
        registrationFee: _num(r['registration_fee']),
        startDate:
            r['start_date'] == null ? null : _parseDate(r['start_date']),
        isActive: r['is_active'] as bool? ?? true,
        createdAt: _parseDate(r['created_at']),
      );

  static Map<String, dynamic> _memberToRow(Member m) => _withId(m.id, {
        'yojna_id': m.yojnaId,
        'name': m.name,
        'father_or_husband_name': m.fatherOrHusbandName,
        'jati': m.jati,
        'gotra': m.gotra,
        'dob': m.dob == null ? null : _date(m.dob!),
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
        'agent_id': m.agentId,
        if (m.consentAt != null) 'consent_at': m.consentAt!.toIso8601String(),
        'join_date': _date(m.joinDate),
        'status': m.status.name,
        'closing_date': m.closingDate == null ? null : _date(m.closingDate!),
        'closing_group': m.closingGroup,
        'photo_url': m.photoUrl,
        'email': m.email.trim().toLowerCase(),
      });

  static Member _memberFromRow(Map<String, dynamic> r) => Member(
        id: r['id'] as String,
        yojnaId: r['yojna_id'] as String,
        regNo: r['reg_no'] as String? ?? '',
        name: r['name'] as String,
        fatherOrHusbandName: r['father_or_husband_name'] as String? ?? '',
        jati: r['jati'] as String? ?? '',
        gotra: r['gotra'] as String? ?? '',
        dob: r['dob'] == null ? null : _parseDate(r['dob']),
        warisName: r['waris_name'] as String? ?? '',
        warisRelation: r['waris_relation'] as String? ?? '',
        gender: Gender.fromName(r['gender'] as String?),
        primaryPhone: r['primary_phone'] as String? ?? '',
        altPhone: r['alt_phone'] as String? ?? '',
        // Encrypted at rest, so this comes back empty (§7); only the last
        // four digits are readable, for the masked display.
        aadhaar: r['aadhaar'] as String? ?? '',
        storedAadhaarLast4: r['aadhaar_last4'] as String? ?? '',
        village: r['village'] as String? ?? '',
        tehsil: r['tehsil'] as String? ?? '',
        district: r['district'] as String? ?? '',
        state: r['state'] as String? ?? '',
        pincode: r['pincode'] as String? ?? '',
        agentId: r['agent_id'] as String?,
        joinDate: _parseDate(r['join_date']),
        status: MemberStatus.fromName(r['status'] as String?),
        closingDate: r['closing_date'] == null ? null : _parseDate(r['closing_date']),
        closingGroup: r['closing_group'] as String?,
        reviewNote: r['review_note'] as String? ?? '',
        consentAt: _parseTimestamp(r['consent_at']),
        photoUrl: r['photo_url'] as String? ?? '',
        email: r['email'] as String? ?? '',
      );

  static Map<String, dynamic> _agentToRow(Agent a) => _withId(a.id, {
        'name': a.name,
        'phone': a.phone,
        'email': a.email,
        'area': a.area,
        'district': a.district,
        'commission_percent': a.commissionPercent,
        'yojna_ids': a.yojnaIds,
        'is_active': a.isActive,
        'join_date': _date(a.joinDate),
      });

  static Agent _agentFromRow(Map<String, dynamic> r) => Agent(
        id: r['id'] as String,
        code: r['code'] as String,
        name: r['name'] as String,
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String? ?? '',
        area: r['area'] as String? ?? '',
        district: r['district'] as String? ?? '',
        commissionPercent: _num(r['commission_percent']),
        yojnaIds: (r['yojna_ids'] as List?)?.cast<String>() ?? const <String>[],
        isActive: r['is_active'] as bool? ?? true,
        joinDate: _parseDate(r['join_date']),
      );

  static Map<String, dynamic> _paymentToRow(Payment p) => _withId(p.id, {
        'member_id': p.memberId,
        'yojna_id': p.yojnaId,
        'amount': p.amount,
        'date': _date(p.date),
        'mode': p.mode.name,
        'status': p.status.name,
        'kind': p.kind.name,
        'agent_id': p.agentId,
        'reference': p.reference,
        'note': p.note,
        'closing_case_id': p.closingCaseId,
      });

  static Payment _paymentFromRow(Map<String, dynamic> r) => Payment(
        id: r['id'] as String,
        receiptNo: r['receipt_no'] as String,
        memberId: r['member_id'] as String,
        yojnaId: r['yojna_id'] as String,
        amount: _num(r['amount']),
        date: _parseDate(r['date']),
        mode: PaymentMode.fromName(r['mode'] as String?),
        status: PaymentStatus.fromName(r['status'] as String?),
        kind: PaymentKind.fromName(r['kind'] as String?),
        agentId: r['agent_id'] as String?,
        reference: r['reference'] as String? ?? '',
        note: r['note'] as String? ?? '',
        closingCaseId: r['closing_case_id'] as String?,
        source: PaymentSource.fromName(r['source'] as String?),
        rejectReason: r['reject_reason'] as String? ?? '',
        cancelledAt: _parseTimestamp(r['cancelled_at']),
        cancelReason: r['cancel_reason'] as String? ?? '',
        cancelRequestedAt: _parseTimestamp(r['cancel_requested_at']),
        cancelRequestReason: r['cancel_request_reason'] as String? ?? '',
      );

  static Map<String, dynamic> _closingToRow(ClosingCase c) => _withId(c.id, {
        'member_id': c.memberId,
        'yojna_id': c.yojnaId,
        'closing_date': _date(c.closingDate),
        'closing_group': c.closingGroup,
        'claim_amount': c.claimAmount,
        'collected_amount': c.collectedAmount,
        'pay_status': c.payStatus.name,
        'nominee_name': c.nomineeName,
        'remarks': c.remarks,
      });

  static ClosingCase _closingFromRow(Map<String, dynamic> r) => ClosingCase(
        id: r['id'] as String,
        memberId: r['member_id'] as String,
        yojnaId: r['yojna_id'] as String,
        closingDate: _parseDate(r['closing_date']),
        closingGroup: r['closing_group'] as String? ?? '',
        claimAmount: _num(r['claim_amount']),
        collectedAmount: _num(r['collected_amount']),
        payStatus: ClosingPayStatus.fromName(r['pay_status'] as String?),
        nomineeName: r['nominee_name'] as String? ?? '',
        remarks: r['remarks'] as String? ?? '',
      );
}
