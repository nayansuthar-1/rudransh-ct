import 'package:flutter/foundation.dart';

enum Gender {
  male('Male'),
  female('Female'),
  other('Other');

  const Gender(this.label);
  final String label;

  static Gender fromName(String? value) =>
      Gender.values.firstWhere((g) => g.name == value, orElse: () => Gender.male);
}

enum MemberStatus {
  active('Active'),
  inactive('Inactive'),
  closed('Closed'),

  /// Added by an agent, waiting for an admin. No registration number yet.
  pending('Pending');

  const MemberStatus(this.label);
  final String label;

  static MemberStatus fromName(String? value) => MemberStatus.values
      .firstWhere((s) => s.name == value, orElse: () => MemberStatus.active);
}

/// A trust member enrolled into one Yojna.
@immutable
class Member {
  const Member({
    required this.id,
    required this.yojnaId,
    required this.regNo,
    required this.name,
    required this.fatherOrHusbandName,
    required this.jati,
    this.gotra = '',
    this.dob,
    required this.warisName,
    required this.warisRelation,
    this.gender = Gender.male,
    required this.primaryPhone,
    this.altPhone = '',
    required this.aadhaar,
    this.storedAadhaarLast4 = '',
    this.village = '',
    this.tehsil = '',
    this.district = '',
    this.state = '',
    this.pincode = '',
    this.agentId,
    required this.joinDate,
    this.status = MemberStatus.active,
    this.closingDate,
    this.closingGroup,
    this.reviewNote = '',
    this.consentAt,
    this.photoUrl = '',
    this.email = '',
    this.contributionAmount = 0,
  });

  final String id;
  final String yojnaId;

  /// Human readable registration number, e.g. `SSY-2026-0184`.
  final String regNo;
  final String name;
  final String fatherOrHusbandName;
  final String jati;
  final String gotra;

  /// Date of birth, printed on the membership certificate. Older records
  /// predate the field, so it can be null.
  final DateTime? dob;

  /// Nominee (waris).
  final String warisName;
  final String warisRelation;
  final Gender gender;
  final String primaryPhone;
  final String altPhone;
  /// Write-only in a real build: the database encrypts it and reads come back
  /// empty, so only [aadhaarLast4] is shown. An owner fetches the full number
  /// on demand (IMPLEMENTATION_PLAN §7).
  final String aadhaar;

  /// Four digits as the database stores them. Use [aadhaarLast4] instead;
  /// this is empty in demo mode, where nothing is encrypted.
  final String storedAadhaarLast4;

  /// Four digits for the masked display, or empty when the member has no
  /// Aadhaar on record.
  String get aadhaarLast4 => storedAadhaarLast4.isNotEmpty
      ? storedAadhaarLast4
      : (aadhaar.length >= 4 ? aadhaar.substring(aadhaar.length - 4) : '');

  final String village;
  final String tehsil;
  final String district;
  final String state;
  final String pincode;
  final String? agentId;
  final DateTime joinDate;
  final MemberStatus status;

  /// Set when the membership is closed (claim raised / settled).
  final DateTime? closingDate;

  /// Batch label used to group closings, e.g. `Group-14`.
  final String? closingGroup;

  /// Why an admin rejected this sign-up, if they did.
  final String reviewNote;

  /// When the member agreed to the trust holding their details
  /// (IMPLEMENTATION_PLAN §7). Null for records enrolled before consent was
  /// recorded — an honest gap rather than a back-dated tick.
  final DateTime? consentAt;

  final String photoUrl;

  /// Optional, stored lowercase. A member whose email is on file can sign in
  /// with it without an invite.
  final String email;

  /// What this member pays for each closing in their Yojna (सहयोग राशि).
  /// Set per member: members of one Yojna pay different amounts.
  final double contributionAmount;

  bool get isClosed => status == MemberStatus.closed;
  bool get isPending => status == MemberStatus.pending;

  String get address => [village, tehsil, district, pincode]
      .where((p) => p.trim().isNotEmpty)
      .join(', ');

  String get searchIndex => [
        name,
        regNo,
        fatherOrHusbandName,
        primaryPhone,
        altPhone,
        aadhaar,
        village,
        district,
        warisName,
      ].join(' ').toLowerCase();

  Member copyWith({
    String? id,
    String? yojnaId,
    String? regNo,
    String? name,
    String? fatherOrHusbandName,
    String? jati,
    String? gotra,
    DateTime? dob,
    bool clearDob = false,
    String? warisName,
    String? warisRelation,
    Gender? gender,
    String? primaryPhone,
    String? altPhone,
    String? aadhaar,
    String? village,
    String? tehsil,
    String? district,
    String? state,
    String? pincode,
    String? agentId,
    bool clearAgent = false,
    DateTime? joinDate,
    MemberStatus? status,
    DateTime? closingDate,
    String? closingGroup,
    bool clearClosing = false,
    String? reviewNote,
    DateTime? consentAt,
    String? photoUrl,
    String? email,
    double? contributionAmount,
  }) {
    return Member(
      id: id ?? this.id,
      yojnaId: yojnaId ?? this.yojnaId,
      regNo: regNo ?? this.regNo,
      name: name ?? this.name,
      fatherOrHusbandName: fatherOrHusbandName ?? this.fatherOrHusbandName,
      jati: jati ?? this.jati,
      gotra: gotra ?? this.gotra,
      dob: clearDob ? null : (dob ?? this.dob),
      warisName: warisName ?? this.warisName,
      warisRelation: warisRelation ?? this.warisRelation,
      gender: gender ?? this.gender,
      primaryPhone: primaryPhone ?? this.primaryPhone,
      altPhone: altPhone ?? this.altPhone,
      aadhaar: aadhaar ?? this.aadhaar,
      storedAadhaarLast4: storedAadhaarLast4,
      village: village ?? this.village,
      tehsil: tehsil ?? this.tehsil,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      closingDate: clearClosing ? null : (closingDate ?? this.closingDate),
      closingGroup: clearClosing ? null : (closingGroup ?? this.closingGroup),
      reviewNote: reviewNote ?? this.reviewNote,
      consentAt: consentAt ?? this.consentAt,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      contributionAmount: contributionAmount ?? this.contributionAmount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'yojnaId': yojnaId,
        'regNo': regNo,
        'name': name,
        'fatherOrHusbandName': fatherOrHusbandName,
        'jati': jati,
        'gotra': gotra,
        'dob': dob?.toIso8601String(),
        'warisName': warisName,
        'warisRelation': warisRelation,
        'gender': gender.name,
        'primaryPhone': primaryPhone,
        'altPhone': altPhone,
        'aadhaar': aadhaar,
        'village': village,
        'tehsil': tehsil,
        'district': district,
        'state': state,
        'pincode': pincode,
        'agentId': agentId,
        'joinDate': joinDate.toIso8601String(),
        'status': status.name,
        'closingDate': closingDate?.toIso8601String(),
        'closingGroup': closingGroup,
        'reviewNote': reviewNote,
        'photoUrl': photoUrl,
        'email': email,
        'contributionAmount': contributionAmount,
      };

  factory Member.fromMap(Map<String, dynamic> map) => Member(
        id: map['id'] as String,
        yojnaId: map['yojnaId'] as String,
        regNo: map['regNo'] as String,
        name: map['name'] as String,
        fatherOrHusbandName: map['fatherOrHusbandName'] as String? ?? '',
        jati: map['jati'] as String? ?? '',
        gotra: map['gotra'] as String? ?? '',
        dob: DateTime.tryParse(map['dob'] as String? ?? ''),
        warisName: map['warisName'] as String? ?? '',
        warisRelation: map['warisRelation'] as String? ?? '',
        gender: Gender.fromName(map['gender'] as String?),
        primaryPhone: map['primaryPhone'] as String? ?? '',
        altPhone: map['altPhone'] as String? ?? '',
        aadhaar: map['aadhaar'] as String? ?? '',
        village: map['village'] as String? ?? '',
        tehsil: map['tehsil'] as String? ?? '',
        district: map['district'] as String? ?? '',
        state: map['state'] as String? ?? '',
        pincode: map['pincode'] as String? ?? '',
        agentId: map['agentId'] as String?,
        joinDate:
            DateTime.tryParse(map['joinDate'] as String? ?? '') ??
                DateTime.now(),
        status: MemberStatus.fromName(map['status'] as String?),
        closingDate: DateTime.tryParse(map['closingDate'] as String? ?? ''),
        closingGroup: map['closingGroup'] as String?,
        reviewNote: map['reviewNote'] as String? ?? '',
        photoUrl: map['photoUrl'] as String? ?? '',
        email: map['email'] as String? ?? '',
        contributionAmount:
            (map['contributionAmount'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Member && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
