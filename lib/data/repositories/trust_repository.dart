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

  /// The office's Dues page: one row per active or inactive member matching
  /// [query], most owed first.
  Future<PageResult<MemberDuesSummary>> fetchDuesPage(
    DuesQuery query, {
    required int offset,
    required int limit,
  });

  /// Totals across every page of [query], whatever its standing.
  Future<DuesTotals> fetchDuesTotals(DuesQuery query);

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

  // ---- Notifications and announcements (IMPLEMENTATION_PLAN Phase 14) -------

  /// The signed-in user's own notifications, newest first.
  Future<List<AppNotification>> fetchNotifications({int limit = 30});

  /// How many of them are unread. Cheap enough to poll for the badge.
  Future<int> fetchUnreadCount();

  Future<void> markNotificationRead(int id);

  /// Marks every unread one read; returns how many changed.
  Future<int> markAllNotificationsRead();

  /// Announcements the signed-in user should see, newest first. Admins see
  /// every one; agents and members see their own Yojnas and trust-wide notices.
  Future<List<Announcement>> fetchAnnouncements({int limit = 20});

  /// Admins only. A null [yojnaId] posts to every Yojna. Returns the new id.
  Future<String> postAnnouncement({
    required String title,
    String body = '',
    String? yojnaId,
  });

  /// Admins only.
  Future<void> deleteAnnouncement(String id);

  // ---- Member portal (IMPLEMENTATION_PLAN Phase 15) -------------------------

  /// The signed-in member's own record.
  Future<Membership> fetchMyMembership();

  /// The signed-in member's receipts, newest first.
  Future<List<Payment>> fetchMyPayments({int limit = 50});

  /// Closing groups the signed-in member still owes for, oldest first.
  Future<List<MemberDue>> fetchMyDues();

  /// The member's own closing case, once the office has opened one.
  Future<ClosingCase?> fetchMyClosingCase();

  /// Records a UPI transfer the member made. It waits for an admin, like an
  /// agent's collection. [closingCaseId] null means the registration fee.
  Future<String> submitUpiPayment({
    required double amount,
    required String reference,
    String? closingCaseId,
  });

  /// Opens a Razorpay order for what the member owes on [closingCaseId]. The
  /// server works out the amount.
  Future<OnlineOrder> startOnlinePayment(String closingCaseId);

  /// Confirms a checkout Razorpay reported as paid; returns the receipt
  /// number. The server checks Razorpay's signature before recording it.
  Future<String> confirmOnlinePayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });

  /// Asks the office to correct one detail. One pending request per field.
  Future<String> requestChange(ChangeField field, String newValue);

  /// The signed-in member's own corrections, newest first.
  Future<List<ChangeRequest>> fetchMyChangeRequests();

  /// Admins: corrections waiting for a decision, oldest first.
  Future<List<ChangeRequest>> fetchPendingChangeRequests();

  /// Admins: applies the change to the member and closes the request.
  Future<void> approveChangeRequest(String id);

  Future<void> rejectChangeRequest(String id, String reason);

  // ---- Cash handovers and commission (IMPLEMENTATION_PLAN Phase 16) --------

  /// Cash agents say they handed over, waiting for an admin to confirm it.
  Future<List<CashHandover>> fetchPendingHandovers();

  /// The office received the money.
  Future<void> confirmHandover(String id);

  /// The office did not receive it: the receipts unlink and the money goes
  /// back to the agent's cash in hand.
  Future<void> rejectHandover(String id, String reason);

  /// Every active agent's commission for one calendar month.
  Future<List<CommissionMonth>> fetchCommissionReport(DateTime month);

  /// Owners only. [amount] null means the calculated commission. Paying a
  /// month that was already paid corrects it.
  Future<void> markCommissionPaid({
    required String agentId,
    required DateTime month,
    double? amount,
    String reference = '',
  });

  // ---- Aadhaar (IMPLEMENTATION_PLAN §7) -----------------------------------

  /// The full number, decrypted. Owners only — the database refuses anyone
  /// else. Returns an empty string when the member has no Aadhaar on record.
  Future<String> fetchMemberAadhaar(String memberId);

  /// Everything the trust holds about one member, for a data request.
  /// Owners only; the Aadhaar comes back decrypted.
  Future<Map<String, dynamic>> exportMemberData(String memberId);

  /// Anonymises the member on request and keeps their receipts, which are
  /// financial records the trust must retain. Owners only, and irreversible.
  Future<void> eraseMemberData(String memberId, String reason);
}
