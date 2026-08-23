import 'package:flutter/foundation.dart';

/// A field agent who enrols members and collects contributions.
@immutable
class Agent {
  const Agent({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    this.email = '',
    this.area = '',
    this.district = '',
    this.commissionPercent = 0,
    this.yojnaIds = const <String>[],
    this.isActive = true,
    required this.joinDate,
  });

  final String id;

  /// Short agent code, e.g. `AG-007`.
  final String code;
  final String name;
  final String phone;
  final String email;
  final String area;
  final String district;
  final double commissionPercent;

  /// Schemes this agent is allowed to work on. Empty means all.
  final List<String> yojnaIds;
  final bool isActive;
  final DateTime joinDate;

  String get searchIndex =>
      [name, code, phone, email, area, district].join(' ').toLowerCase();

  Agent copyWith({
    String? id,
    String? code,
    String? name,
    String? phone,
    String? email,
    String? area,
    String? district,
    double? commissionPercent,
    List<String>? yojnaIds,
    bool? isActive,
    DateTime? joinDate,
  }) {
    return Agent(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      area: area ?? this.area,
      district: district ?? this.district,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      yojnaIds: yojnaIds ?? this.yojnaIds,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'phone': phone,
        'email': email,
        'area': area,
        'district': district,
        'commissionPercent': commissionPercent,
        'yojnaIds': yojnaIds,
        'isActive': isActive,
        'joinDate': joinDate.toIso8601String(),
      };

  factory Agent.fromMap(Map<String, dynamic> map) => Agent(
        id: map['id'] as String,
        code: map['code'] as String? ?? '',
        name: map['name'] as String,
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        area: map['area'] as String? ?? '',
        district: map['district'] as String? ?? '',
        commissionPercent: (map['commissionPercent'] as num?)?.toDouble() ?? 0,
        yojnaIds:
            (map['yojnaIds'] as List?)?.map((e) => e as String).toList() ??
                const <String>[],
        isActive: map['isActive'] as bool? ?? true,
        joinDate:
            DateTime.tryParse(map['joinDate'] as String? ?? '') ??
                DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Agent && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
