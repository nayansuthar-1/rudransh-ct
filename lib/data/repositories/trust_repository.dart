import '../models/models.dart';

/// A failure the UI can show as-is (forms print the exception with `'$e'`).
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Data access contract for the whole admin panel.
///
/// The app talks only to this interface, so swapping the in-memory
/// [InMemoryTrustRepository] for [SupabaseTrustRepository] is decided in
/// `lib/state/providers.dart`.
abstract class TrustRepository {
  // ---- Yojna -------------------------------------------------------------
  Future<List<Yojna>> fetchYojnas();
  Future<Yojna> createYojna(Yojna yojna);
  Future<Yojna> updateYojna(Yojna yojna);
  Future<void> deleteYojna(String id);

  // ---- Members -----------------------------------------------------------

  /// One page of members matching [query], newest joiners first.
  Future<PageResult<Member>> fetchMembersPage(
    MemberQuery query, {
    required int offset,
    required int limit,
  });

  /// Members by id, for screens that show a few specific members.
  Future<List<Member>> fetchMembersByIds(Iterable<String> ids);

  /// Type-ahead lookup by name, reg no or phone.
  Future<List<Member>> searchMembers(
    String text, {
    int limit = 20,
    bool excludeClosed = false,
  });

  /// Distinct non-empty districts, for the members filter.
  Future<List<String>> fetchMemberDistricts();

  Future<Member> createMember(Member member);
  Future<Member> updateMember(Member member);
  Future<void> deleteMember(String id);

  /// Used by the "Copy details from an existing member" lookup in the add-member form.
  Future<Member?> findMemberByPhone(String phone);

  /// Next registration number for a scheme, e.g. `SSY-2026-0184`.
  Future<String> nextRegNo(String yojnaId);

  // ---- Agents ------------------------------------------------------------
  Future<List<Agent>> fetchAgents();
  Future<Agent> createAgent(Agent agent);
  Future<Agent> updateAgent(Agent agent);
  Future<void> deleteAgent(String id);
  Future<String> nextAgentCode();

  // ---- Payments ----------------------------------------------------------

  /// One page of payments matching [query], newest first, with their members.
  Future<PaymentPage> fetchPaymentsPage(
    PaymentQuery query, {
    required int offset,
    required int limit,
  });

  /// Count and amount totals across every page of [query].
  Future<PaymentTotals> fetchPaymentTotals(PaymentQuery query);

  Future<Payment> createPayment(Payment payment);
  Future<Payment> updatePayment(Payment payment);
  Future<void> deletePayment(String id);
  Future<String> nextReceiptNo();

  // ---- Closing cases -----------------------------------------------------
  Future<List<ClosingCase>> fetchClosingCases();
  Future<ClosingCase> createClosingCase(ClosingCase value);
  Future<ClosingCase> updateClosingCase(ClosingCase value);
  Future<void> deleteClosingCase(String id);

  // ---- Aggregates --------------------------------------------------------

  /// Dashboard tiles for one scheme, or all schemes when [yojnaId] is null.
  Future<DashboardStats> fetchDashboardStats(String? yojnaId);

  /// Member count per scheme id.
  Future<Map<String, int>> fetchMembersPerYojna();

  /// Member count per agent id.
  Future<Map<String, int>> fetchMemberCountByAgent();

  /// Paid collection per agent id.
  Future<Map<String, double>> fetchCollectionByAgent();

  // ---- Approvals (IMPLEMENTATION_PLAN Phase 12) ---------------------------

  /// Members added by agents and waiting for an admin, oldest first.
  Future<List<Member>> fetchPendingMembers();

  /// Payments from agents or members waiting for approval, oldest first.
  /// Office-entered pending payments are unpaid dues and are not included.
  Future<PaymentPage> fetchPendingPayments();

  /// Receipts an agent asked to cancel, oldest first.
  Future<PaymentPage> fetchCancelRequests();

  /// Returns the registration number the member receives.
  Future<String> approveMember(String memberId);
  Future<void> rejectMember(String memberId, String reason);
  Future<void> approvePayment(String paymentId);
  Future<void> rejectPayment(String paymentId, String reason);

  /// Owners only. The receipt stays on record but leaves every total.
  Future<void> cancelPayment(String paymentId, String reason);
  Future<void> declineCancelRequest(String paymentId);

  /// Moves every member of [fromAgentId] to [toAgentId]; returns how many.
  Future<int> reassignMembers(String fromAgentId, String toAgentId);

  // ---- Dues and death reports (IMPLEMENTATION_PLAN Phase 13) ----------------

  /// Closing groups [memberId] owes a contribution for, oldest first.
  Future<List<MemberDue>> fetchMemberDues(String memberId);

  /// Deaths reported by agents and waiting for a decision, oldest first.
  Future<List<ClosingRequest>> fetchPendingClosingRequests();

  /// Creates the closing case from the report, which closes the member.
  /// [claimAmount] defaults to the Yojna's. Returns the case id.
  Future<String> approveClosingRequest(
    String requestId, {
    required String closingGroup,
    double? claimAmount,
  });

  Future<void> rejectClosingRequest(String requestId, String reason);
}
