import 'package:flutter/foundation.dart';

import 'member.dart';

/// Where one member stands for one closing.
enum DueState {
  due('Due'),
  pending('Waiting for approval'),
  paid('Paid');

  const DueState(this.label);
  final String label;
}

/// One member's contribution for one closing (the `member_dues` view).
///
/// A closing is any claim a Yojna pays out, such as a member's wedding in
/// Shadi Sahyog Yojna. Every active member of the Yojna who was added to the
/// app before the closing was created owes one contribution for it, at the
/// Yojna's contribution amount; the member whose closing it is does not.
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
    this.beneficiaryName = '',
    this.memberName = '',
    this.regNo = '',
    this.phone = '',
    this.village = '',
  });

  final String memberId;
  final String yojnaId;
  final String closingCaseId;

  /// A label the office gives closings, such as Group-14. Several closings
  /// can share one; each is still paid for on its own.
  final String closingGroup;
  final DateTime closingDate;

  /// The Yojna's contribution amount.
  final double amount;

  /// Approved contributions for this closing.
  final double paid;

  /// Collected, waiting for an admin.
  final double pending;

  /// The member whose closing it is. Empty where the source does not say.
  final String beneficiaryName;

  // Filled on the agent's dues list.
  final String memberName;
  final String regNo;
  final String phone;
  final String village;

  /// The closing's name on screen: its group, with whose closing it is.
  String get title => [
        closingGroup.isEmpty ? 'Closing' : closingGroup,
        if (beneficiaryName.isNotEmpty) beneficiaryName,
      ].join(' · ');

  /// Still unpaid, ignoring money waiting for approval.
  double get due => (amount - paid).clamp(0, double.infinity);

  /// Still to collect: unpaid and not collected yet.
  double get toCollect => (due - pending).clamp(0, double.infinity);

  DueState get state => due <= 0
      ? DueState.paid
      : (pending > 0 ? DueState.pending : DueState.due);
}

/// One closing as an agent sees it: counts over the agent's own members.
@immutable
class ClosingDues {
  const ClosingDues({
    required this.yojnaId,
    required this.yojnaName,
    required this.closingGroup,
    required this.closingDate,
    required this.closingCaseId,
    required this.memberCount,
    required this.paidCount,
    required this.pendingCount,
    required this.dueCount,
    required this.toCollect,
    this.beneficiaryName = '',
  });

  final String yojnaId;
  final String yojnaName;
  final String closingGroup;
  final DateTime closingDate;
  final String closingCaseId;

  /// The member whose closing it is.
  final String beneficiaryName;
  final int memberCount;
  final int paidCount;
  final int pendingCount;
  final int dueCount;
  final double toCollect;

  /// The group label, or a stand-in when the closing has none.
  String get groupLabel => closingGroup.isEmpty ? 'Closing' : closingGroup;

  /// Folds one closing's dues rows into a summary.
  factory ClosingDues.of(List<MemberDue> dues, {required String yojnaName}) {
    final first = dues.first;
    int count(DueState s) => dues.where((d) => d.state == s).length;
    return ClosingDues(
      yojnaId: first.yojnaId,
      yojnaName: yojnaName,
      closingGroup: first.closingGroup,
      closingDate: first.closingDate,
      closingCaseId: first.closingCaseId,
      beneficiaryName: first.beneficiaryName,
      memberCount: dues.length,
      paidCount: count(DueState.paid),
      pendingCount: count(DueState.pending),
      dueCount: count(DueState.due),
      toCollect: dues.fold(0, (sum, d) => sum + d.toCollect),
    );
  }
}

/// Which members the office's Dues page lists.
enum DuesStanding {
  owing('Owes money'),
  clear('Nothing due');

  const DuesStanding(this.label);
  final String label;
}

/// One member's standing across every closing group of their Yojna, for the
/// office's Dues page (the `office_member_dues` function).
@immutable
class MemberDuesSummary {
  const MemberDuesSummary({
    required this.memberId,
    required this.yojnaId,
    required this.regNo,
    required this.name,
    required this.joinDate,
    this.phone = '',
    this.village = '',
    this.agentId,
    this.status = MemberStatus.active,
    this.closingsOwed = 0,
    this.due = 0,
    this.pending = 0,
    this.contributed = 0,
    this.lastContribution,
    this.contributionAmount = 0,
  });

  final String memberId;
  final String yojnaId;
  final String regNo;
  final String name;
  final DateTime joinDate;
  final String phone;
  final String village;
  final String? agentId;
  final MemberStatus status;

  /// Closing groups not fully paid yet.
  final int closingsOwed;

  /// Still unpaid across those groups, ignoring money waiting for approval.
  final double due;

  /// Collected for a closing, waiting for an admin.
  final double pending;

  /// Every approved contribution the member has paid.
  final double contributed;
  final DateTime? lastContribution;

  /// What the member pays for each closing.
  final double contributionAmount;

  bool get owes => due > 0;

  /// Enough of the member for the payment form, which only shows who pays.
  Member toMember() => Member(
        id: memberId,
        yojnaId: yojnaId,
        regNo: regNo,
        name: name,
        fatherOrHusbandName: '',
        jati: '',
        warisName: '',
        warisRelation: '',
        primaryPhone: phone,
        aadhaar: '',
        village: village,
        agentId: agentId,
        joinDate: joinDate,
        status: status,
        contributionAmount: contributionAmount,
      );
}

/// The tiles on the office's Dues page, across every page of the list.
@immutable
class DuesTotals {
  const DuesTotals({
    required this.memberCount,
    required this.owingCount,
    required this.due,
    required this.pending,
    required this.contributed,
  });

  static const empty = DuesTotals(
    memberCount: 0,
    owingCount: 0,
    due: 0,
    pending: 0,
    contributed: 0,
  );

  final int memberCount;
  final int owingCount;
  final double due;
  final double pending;
  final double contributed;
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

/// An agent's report that a member's closing is due (such as their wedding in
/// Shadi Sahyog Yojna), with the proof document on Cloudinary.
/// An admin approves it into a closing case, or rejects it with a reason.
@immutable
class ClosingRequest {
  const ClosingRequest({
    required this.id,
    required this.memberId,
    required this.eventDate,
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
  final DateTime eventDate;
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
      eventDate: eventDate,
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
