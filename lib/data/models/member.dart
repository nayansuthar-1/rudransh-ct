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
  closed('Closed');

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
    required this.warisName,
    required this.warisRelation,
    this.gender = Gender.male,
    required this.primaryPhone,
    this.altPhone = '',
    required this.aadhaar,
    this.village = '',
    this.tehsil = '',
    this.district = '',
    this.pincode = '',
    this.agentId,
    required this.joinDate,
    this.status = MemberStatus.active,
    this.closingDate,
    this.closingGroup,
  });

  final String id;
  final String yojnaId;

  /// Human readable registration number, e.g. `SSY-2026-0184`.
  final String regNo;
  final String name;
  final String fatherOrHusbandName;
  final String jati;
  final String gotra;

  /// Nominee (waris).
  final String warisName;
  final String warisRelation;
  final Gender gender;
  final String primaryPhone;
  final String altPhone;
  final String aadhaar;
  final String village;
  final String tehsil;
  final String district;
  final String pincode;
  final String? agentId;
  final DateTime joinDate;
  final MemberStatus status;

  /// Set when the membership is closed (claim raised / settled).
  final DateTime? closingDate;

  /// Batch label used to group closings, e.g. `Group-14`.
  final String? closingGroup;

  bool get isClosed => status == MemberStatus.closed;

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
    String? warisName,
    String? warisRelation,
    Gender? gender,
    String? primaryPhone,
    String? altPhone,
    String? aadhaar,
    String? village,
    String? tehsil,
    String? district,
    String? pincode,
    String? agentId,
    bool clearAgent = false,
    DateTime? joinDate,
    MemberStatus? status,
    DateTime? closingDate,
    String? closingGroup,
    bool clearClosing = false,
  }) {
    return Member(
      id: id ?? this.id,
      yojnaId: yojnaId ?? this.yojnaId,
      regNo: regNo ?? this.regNo,
      name: name ?? this.name,
      fatherOrHusbandName: fatherOrHusbandName ?? this.fatherOrHusbandName,
      jati: jati ?? this.jati,
      gotra: gotra ?? this.gotra,
      warisName: warisName ?? this.warisName,
      warisRelation: warisRelation ?? this.warisRelation,
      gender: gender ?? this.gender,
      primaryPhone: primaryPhone ?? this.primaryPhone,
      altPhone: altPhone ?? this.altPhone,
      aadhaar: aadhaar ?? this.aadhaar,
      village: village ?? this.village,
      tehsil: tehsil ?? this.tehsil,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      closingDate: clearClosing ? null : (closingDate ?? this.closingDate),
      closingGroup: clearClosing ? null : (closingGroup ?? this.closingGroup),
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
        'warisName': warisName,
        'warisRelation': warisRelation,
        'gender': gender.name,
        'primaryPhone': primaryPhone,
        'altPhone': altPhone,
        'aadhaar': aadhaar,
        'village': village,
        'tehsil': tehsil,
        'district': district,
        'pincode': pincode,
        'agentId': agentId,
        'joinDate': joinDate.toIso8601String(),
        'status': status.name,
        'closingDate': closingDate?.toIso8601String(),
        'closingGroup': closingGroup,
      };

  factory Member.fromMap(Map<String, dynamic> map) => Member(
        id: map['id'] as String,
        yojnaId: map['yojnaId'] as String,
        regNo: map['regNo'] as String,
        name: map['name'] as String,
        fatherOrHusbandName: map['fatherOrHusbandName'] as String? ?? '',
        jati: map['jati'] as String? ?? '',
        gotra: map['gotra'] as String? ?? '',
        warisName: map['warisName'] as String? ?? '',
        warisRelation: map['warisRelation'] as String? ?? '',
        gender: Gender.fromName(map['gender'] as String?),
        primaryPhone: map['primaryPhone'] as String? ?? '',
        altPhone: map['altPhone'] as String? ?? '',
        aadhaar: map['aadhaar'] as String? ?? '',
        village: map['village'] as String? ?? '',
        tehsil: map['tehsil'] as String? ?? '',
        district: map['district'] as String? ?? '',
        pincode: map['pincode'] as String? ?? '',
        agentId: map['agentId'] as String?,
        joinDate:
            DateTime.tryParse(map['joinDate'] as String? ?? '') ??
                DateTime.now(),
        status: MemberStatus.fromName(map['status'] as String?),
        closingDate: DateTime.tryParse(map['closingDate'] as String? ?? ''),
        closingGroup: map['closingGroup'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Member && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
