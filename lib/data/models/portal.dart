import 'package:flutter/foundation.dart';

import 'dues.dart';
import 'member.dart';
import 'payment.dart';

/// What the public `/lookup` page shows (IMPLEMENTATION_PLAN Phase 15).
///
/// A member's standing, plus their own papers: [member] carries the fields
/// their certificate prints and [receipts] their approved receipts, so a
/// member with no login can print both. Never the Aadhaar number — [member]
/// is built without it.
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
    this.member,
    this.payoutNote = '',
    this.yojnaStartedOn,
    this.agentName = '',
    this.receipts = const [],
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

  /// The member as their certificate and receipts print them. Null from a
  /// server that predates the `details` column.
  final Member? member;

  /// The Yojna's `नोंध` and start date, for the certificate.
  final String payoutNote;
  final DateTime? yojnaStartedOn;

  final String agentName;

  /// Approved, not cancelled, newest first.
  final List<Payment> receipts;

  static MemberLookup fromRow(Map<String, dynamic> r) {
    final regNo = (r['reg_no'] ?? '') as String;
    final name = (r['name'] ?? '') as String;
    final status = MemberStatus.fromName(r['status'] as String?);
    final joinDate = DateTime.parse(r['join_date'] as String);
    final details = r['details'] is Map
        ? Map<String, dynamic>.from(r['details'] as Map)
        : null;
    final cert = details?['certificate'] is Map
        ? Map<String, dynamic>.from(details!['certificate'] as Map)
        : null;
    String text(String key) => (cert?[key] ?? '') as String;

    return MemberLookup(
      regNo: regNo,
      name: name,
      yojnaName: (r['yojna_name'] ?? '') as String,
      status: status,
      joinDate: joinDate,
      contributionAmount: _num(r['contribution_amount']),
      duesCount: (r['dues_count'] as num?)?.toInt() ?? 0,
      duesAmount: _num(r['dues_amount']),
      member: cert == null
          ? null
          : Member(
              id: '',
              yojnaId: '',
              regNo: regNo,
              name: name,
              fatherOrHusbandName: text('father_or_husband_name'),
              jati: text('jati'),
              gotra: text('gotra'),
              dob: _date(cert['dob']),
              warisName: text('waris_name'),
              warisRelation: text('waris_relation'),
              primaryPhone: text('primary_phone'),
              aadhaar: '',
              village: text('village'),
              tehsil: text('tehsil'),
              district: text('district'),
              state: text('state'),
              pincode: text('pincode'),
              joinDate: joinDate,
              status: status,
              photoUrl: text('photo_url'),
            ),
      payoutNote: text('yojna_description'),
      yojnaStartedOn: _date(cert?['yojna_start_date']),
      agentName: text('agent_name'),
      receipts: [
        for (final p in (details?['receipts'] as List?) ?? const [])
          _receipt(Map<String, dynamic>.from(p as Map)),
      ],
    );
  }

  static Payment _receipt(Map<String, dynamic> p) => Payment(
        id: (p['receipt_no'] ?? '') as String,
        receiptNo: (p['receipt_no'] ?? '') as String,
        memberId: '',
        yojnaId: '',
        amount: _num(p['amount']),
        date: DateTime.parse(p['date'] as String),
        mode: PaymentMode.fromName(p['mode'] as String?),
        kind: PaymentKind.fromName(p['kind'] as String?),
        reference: (p['reference'] ?? '') as String,
        closingGroup: (p['closing_group'] ?? '') as String,
      );
}

/// An online payment the server has opened with Razorpay, ready for the
/// checkout. [amountPaise] is what the member will be charged.
@immutable
class OnlineOrder {
  const OnlineOrder({
    required this.orderId,
    required this.amountPaise,
    required this.keyId,
    this.currency = 'INR',
    this.name = '',
    this.description = '',
    this.prefillName = '',
    this.prefillEmail = '',
    this.prefillContact = '',
  });

  final String orderId;
  final int amountPaise;
  final String keyId;
  final String currency;
  final String name;
  final String description;
  final String prefillName;
  final String prefillEmail;
  final String prefillContact;

  static OnlineOrder fromJson(Map<String, dynamic> j) {
    final prefill = j['prefill'] is Map
        ? Map<String, dynamic>.from(j['prefill'] as Map)
        : const <String, dynamic>{};
    return OnlineOrder(
      orderId: j['order_id'] as String,
      amountPaise: (j['amount'] as num).toInt(),
      keyId: j['key_id'] as String,
      currency: (j['currency'] ?? 'INR') as String,
      name: (j['name'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      prefillName: (prefill['name'] ?? '') as String,
      prefillEmail: (prefill['email'] ?? '') as String,
      prefillContact: (prefill['contact'] ?? '') as String,
    );
  }
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
    this.jati = '',
    this.gotra = '',
    this.dob,
    this.state = '',
    this.email = '',
    this.photoUrl = '',
    this.payoutNote = '',
    this.yojnaStartedOn,
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

  /// The rest of what the member's certificate prints.
  final String jati;
  final String gotra;
  final DateTime? dob;
  final String state;
  final String email;
  final String photoUrl;

  /// The Yojna's `नोंध` and start date, for the certificate.
  final String payoutNote;
  final DateTime? yojnaStartedOn;

  /// The member as the certificate and receipts print them. Never carries
  /// the Aadhaar number.
  Member toMember() => Member(
        id: memberId,
        yojnaId: yojnaId,
        regNo: regNo,
        name: name,
        fatherOrHusbandName: fatherOrHusbandName,
        jati: jati,
        gotra: gotra,
        dob: dob,
        warisName: warisName,
        warisRelation: warisRelation,
        primaryPhone: primaryPhone,
        altPhone: altPhone,
        aadhaar: '',
        village: village,
        tehsil: tehsil,
        district: district,
        state: state,
        pincode: pincode,
        joinDate: joinDate,
        status: status,
        photoUrl: photoUrl,
        email: email,
      );

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
        jati: (r['jati'] ?? '') as String,
        gotra: (r['gotra'] ?? '') as String,
        dob: _date(r['dob']),
        state: (r['state'] ?? '') as String,
        email: (r['email'] ?? '') as String,
        photoUrl: (r['photo_url'] ?? '') as String,
        payoutNote: (r['yojna_description'] ?? '') as String,
        yojnaStartedOn: _date(r['yojna_start_date']),
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

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.parse(v) : null;
