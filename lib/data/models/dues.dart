import 'package:flutter/foundation.dart';

/// Where one member stands for one closing group.
enum DueState {
  due('Due'),
  pending('Waiting for approval'),
  paid('Paid');

  const DueState(this.label);
  final String label;
}

/// One member's contribution for one closing group (the `member_dues` view,
/// IMPLEMENTATION_PLAN Phase 13).
///
/// Every active member of a Yojna who joined before the group's first
/// closing date owes one contribution at the Yojna's contribution amount.
@immutable
class MemberDue {
  const MemberDue({
    required this.memberId,
    required this.yojnaId,
    required this.closingCaseId,
    required this.closingGroup,
    required this.closingDate,
    required this.amount,
    this.paid = 0,
    this.pending = 0,
    this.memberName = '',
    this.regNo = '',
    this.phone = '',
    this.village = '',
  });

  final String memberId;
  final String yojnaId;

  /// The group's first closing case; contributions for the group link to it.
  final String closingCaseId;
  final String closingGroup;
  final DateTime closingDate;

  /// The Yojna's contribution amount.
  final double amount;

  /// Approved contributions for this group.
  final double paid;

  /// Collected, waiting for an admin.
  final double pending;

  // Filled on the agent's dues list.
  final String memberName;
  final String regNo;
  final String phone;
  final String village;

  /// Still unpaid, ignoring money waiting for approval.
  double get due => (amount - paid).clamp(0, double.infinity);

  /// Still to collect: unpaid and not collected yet.
  double get toCollect => (due - pending).clamp(0, double.infinity);

  DueState get state => due <= 0
      ? DueState.paid
      : (pending > 0 ? DueState.pending : DueState.due);
}

/// A closing group as an agent sees it: counts over the agent's own members.
@immutable
class ClosingGroupDues {
  const ClosingGroupDues({
    required this.yojnaId,
    required this.yojnaName,
    required this.closingGroup,
    required this.closingDate,
    required this.closingCaseId,
    required this.caseCount,
    required this.memberCount,
    required this.paidCount,
    required this.pendingCount,
    required this.dueCount,
    required this.toCollect,
  });

  final String yojnaId;
  final String yojnaName;
  final String closingGroup;

  /// First closing date in the group.
  final DateTime closingDate;
  final String closingCaseId;

  /// Deaths in the group.
  final int caseCount;
  final int memberCount;
  final int paidCount;
  final int pendingCount;
  final int dueCount;
  final double toCollect;

  /// Folds one group's dues rows into a summary.
  factory ClosingGroupDues.of(
    List<MemberDue> dues, {
    required String yojnaName,
    required int caseCount,
  }) {
    final first = dues.first;
    int count(DueState s) => dues.where((d) => d.state == s).length;
    return ClosingGroupDues(
      yojnaId: first.yojnaId,
      yojnaName: yojnaName,
      closingGroup: first.closingGroup,
      closingDate: first.closingDate,
      closingCaseId: first.closingCaseId,
      caseCount: caseCount,
      memberCount: dues.length,
      paidCount: count(DueState.paid),
      pendingCount: count(DueState.pending),
      dueCount: count(DueState.due),
      toCollect: dues.fold(0, (sum, d) => sum + d.toCollect),
    );
  }
}

enum RequestStatus {
  pending('Waiting for office'),
  approved('Approved'),
  rejected('Rejected');

  const RequestStatus(this.label);
  final String label;

  static RequestStatus fromName(String? value) => RequestStatus.values
      .firstWhere((s) => s.name == value, orElse: () => RequestStatus.pending);
}

/// An agent's report of a member's death, with the certificate on Cloudinary.
/// An admin approves it into a closing case, or rejects it with a reason.
@immutable
class ClosingRequest {
  const ClosingRequest({
    required this.id,
    required this.memberId,
    required this.dateOfDeath,
    required this.certificateUrl,
    this.memberName = '',
    this.memberRegNo = '',
    this.yojnaId = '',
    this.agentId,
    this.nomineeName = '',
    this.nomineeRelation = '',
    this.remarks = '',
    this.status = RequestStatus.pending,
    this.decisionNote = '',
    this.closingCaseId,
    this.createdAt,
  });

  final String id;
  final String memberId;
  final String memberName;
  final String memberRegNo;
  final String yojnaId;
  final String? agentId;
  final DateTime dateOfDeath;
  final String nomineeName;
  final String nomineeRelation;
  final String certificateUrl;
  final String remarks;
  final RequestStatus status;

  /// Why the office rejected it.
  final String decisionNote;
  final String? closingCaseId;
  final DateTime? createdAt;

  ClosingRequest copyWith({
    String? id,
    String? memberName,
    String? memberRegNo,
    String? yojnaId,
    String? agentId,
    RequestStatus? status,
    String? decisionNote,
    String? closingCaseId,
    DateTime? createdAt,
  }) {
    return ClosingRequest(
      id: id ?? this.id,
      memberId: memberId,
      memberName: memberName ?? this.memberName,
      memberRegNo: memberRegNo ?? this.memberRegNo,
      yojnaId: yojnaId ?? this.yojnaId,
      agentId: agentId ?? this.agentId,
      dateOfDeath: dateOfDeath,
      nomineeName: nomineeName,
      nomineeRelation: nomineeRelation,
      certificateUrl: certificateUrl,
      remarks: remarks,
      status: status ?? this.status,
      decisionNote: decisionNote ?? this.decisionNote,
      closingCaseId: closingCaseId ?? this.closingCaseId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ClosingRequest && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
