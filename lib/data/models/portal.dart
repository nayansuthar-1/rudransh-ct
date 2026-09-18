import 'package:flutter/foundation.dart';

import 'dues.dart';
import 'member.dart';

/// What the public `/lookup` page shows (IMPLEMENTATION_PLAN Phase 15).
///
/// Deliberately thin: no Aadhaar, no address, no agent. Anyone with a
/// registration number and phone can see this, so it holds only what a member
/// needs to confirm their own standing.
@immutable
class MemberLookup {
  const MemberLookup({
    required this.regNo,
    required this.name,
    required this.yojnaName,
    required this.status,
    required this.joinDate,
    required this.contributionAmount,
    this.duesCount = 0,
    this.duesAmount = 0,
  });

  final String regNo;
  final String name;
  final String yojnaName;
  final MemberStatus status;
  final DateTime joinDate;
  final double contributionAmount;

  /// Closing groups still owed.
  final int duesCount;
  final double duesAmount;

  bool get owesNothing => duesAmount <= 0;

  static MemberLookup fromRow(Map<String, dynamic> r) => MemberLookup(
        regNo: (r['reg_no'] ?? '') as String,
        name: (r['name'] ?? '') as String,
        yojnaName: (r['yojna_name'] ?? '') as String,
        status: MemberStatus.fromName(r['status'] as String?),
        joinDate: DateTime.parse(r['join_date'] as String),
        contributionAmount: _num(r['contribution_amount']),
        duesCount: (r['dues_count'] as num?)?.toInt() ?? 0,
        duesAmount: _num(r['dues_amount']),
      );
}

/// A signed-in member's own record, as `my_membership` returns it.
@immutable
class Membership {
  const Membership({
    required this.memberId,
    required this.regNo,
    required this.name,
    required this.yojnaId,
    required this.yojnaName,
    required this.contributionAmount,
    required this.joinDate,
    required this.status,
    this.fatherOrHusbandName = '',
    this.warisName = '',
    this.warisRelation = '',
    this.primaryPhone = '',
    this.altPhone = '',
    this.village = '',
    this.tehsil = '',
    this.district = '',
    this.pincode = '',
    this.agentName = '',
  });

  final String memberId;
  final String regNo;
  final String name;
  final String fatherOrHusbandName;
  final String warisName;
  final String warisRelation;
  final String primaryPhone;
  final String altPhone;
  final String village;
  final String tehsil;
  final String district;
  final String pincode;
  final String yojnaId;
  final String yojnaName;
  final double contributionAmount;
  final DateTime joinDate;
  final MemberStatus status;
  final String agentName;

  String get address => [village, tehsil, district, pincode]
      .where((p) => p.trim().isNotEmpty)
      .join(', ');

  static Membership fromRow(Map<String, dynamic> r) => Membership(
        memberId: r['member_id'] as String,
        regNo: (r['reg_no'] ?? '') as String,
        name: (r['name'] ?? '') as String,
        fatherOrHusbandName: (r['father_or_husband_name'] ?? '') as String,
        warisName: (r['waris_name'] ?? '') as String,
        warisRelation: (r['waris_relation'] ?? '') as String,
        primaryPhone: (r['primary_phone'] ?? '') as String,
        altPhone: (r['alt_phone'] ?? '') as String,
        village: (r['village'] ?? '') as String,
        tehsil: (r['tehsil'] ?? '') as String,
        district: (r['district'] ?? '') as String,
        pincode: (r['pincode'] ?? '') as String,
        yojnaId: r['yojna_id'] as String,
        yojnaName: (r['yojna_name'] ?? '') as String,
        contributionAmount: _num(r['contribution_amount']),
        joinDate: DateTime.parse(r['join_date'] as String),
        status: MemberStatus.fromName(r['status'] as String?),
        agentName: (r['agent_name'] ?? '') as String,
      );
}

/// Which member details a member may ask to have corrected. The database
/// `change_requests` table allows exactly this set.
enum ChangeField {
  primaryPhone('primary_phone', 'Phone number'),
  altPhone('alt_phone', 'Alternate phone'),
  village('village', 'Village'),
  tehsil('tehsil', 'Tehsil'),
  district('district', 'District'),
  pincode('pincode', 'PIN code'),
  warisName('waris_name', 'Nominee name'),
  warisRelation('waris_relation', 'Nominee relation'),
  name('name', 'Name'),
  fatherOrHusbandName('father_or_husband_name', "Father's / husband's name");

  const ChangeField(this.column, this.label);
  final String column;
  final String label;

  static ChangeField of(String column) => values.firstWhere(
        (f) => f.column == column,
        orElse: () => ChangeField.village,
      );
}

/// A correction a member asked for, on either side of the decision.
@immutable
class ChangeRequest {
  const ChangeRequest({
    required this.id,
    required this.field,
    required this.newValue,
    required this.createdAt,
    this.memberId = '',
    this.memberName = '',
    this.regNo = '',
    this.oldValue = '',
    this.status = RequestStatus.pending,
    this.decisionNote = '',
  });

  final String id;
  final String memberId;
  final String memberName;
  final String regNo;
  final ChangeField field;
  final String oldValue;
  final String newValue;
  final RequestStatus status;
  final String decisionNote;
  final DateTime createdAt;

  static ChangeRequest fromRow(Map<String, dynamic> r) => ChangeRequest(
        id: r['id'] as String,
        memberId: (r['member_id'] ?? '') as String,
        memberName: (r['member_name'] ?? '') as String,
        regNo: (r['reg_no'] ?? '') as String,
        field: ChangeField.of((r['field'] ?? '') as String),
        oldValue: (r['old_value'] ?? '') as String,
        newValue: (r['new_value'] ?? '') as String,
        status: RequestStatus.fromName(r['status'] as String?),
        decisionNote: (r['decision_note'] ?? '') as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

double _num(Object? v) => v == null ? 0 : (v as num).toDouble();
