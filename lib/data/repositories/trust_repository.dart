import '../models/models.dart';

/// Data access contract for the whole admin panel.
///
/// The app talks only to this interface, so swapping the in-memory
/// [InMemoryTrustRepository] for Firebase / Supabase / a REST backend is a
/// single-line change in `lib/state/providers.dart`.
abstract class TrustRepository {
  // ---- Yojna -------------------------------------------------------------
  Future<List<Yojna>> fetchYojnas();
  Future<Yojna> createYojna(Yojna yojna);
  Future<Yojna> updateYojna(Yojna yojna);
  Future<void> deleteYojna(String id);

  // ---- Members -----------------------------------------------------------
  Future<List<Member>> fetchMembers();
  Future<Member> createMember(Member member);
  Future<Member> updateMember(Member member);
  Future<void> deleteMember(String id);

  /// Used by the "मौजूदा सदस्य से कॉपी करें" lookup in the add-member form.
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
  Future<List<Payment>> fetchPayments();
  Future<Payment> createPayment(Payment payment);
  Future<Payment> updatePayment(Payment payment);
  Future<void> deletePayment(String id);
  Future<String> nextReceiptNo();

  // ---- Closing cases -----------------------------------------------------
  Future<List<ClosingCase>> fetchClosingCases();
  Future<ClosingCase> createClosingCase(ClosingCase value);
  Future<ClosingCase> updateClosingCase(ClosingCase value);
  Future<void> deleteClosingCase(String id);
}
