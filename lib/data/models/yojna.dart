import 'package:flutter/foundation.dart';

/// A scheme / programme (Yojna) run by the trust.
@immutable
class Yojna {
  const Yojna({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.contributionAmount = 0,
    this.claimAmount = 0,
    this.registrationFee = 0,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;

  /// Display name as the trust writes it.
  final String name;

  /// Short uppercase code used in registration numbers (e.g. `SSY`).
  final String code;
  final String description;

  /// Amount each member contributes per closing event.
  final double contributionAmount;

  /// Amount paid out to the nominee on a closing.
  final double claimAmount;
  final double registrationFee;
  final bool isActive;
  final DateTime createdAt;

  Yojna copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    double? contributionAmount,
    double? claimAmount,
    double? registrationFee,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Yojna(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      claimAmount: claimAmount ?? this.claimAmount,
      registrationFee: registrationFee ?? this.registrationFee,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'contributionAmount': contributionAmount,
        'claimAmount': claimAmount,
        'registrationFee': registrationFee,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Yojna.fromMap(Map<String, dynamic> map) => Yojna(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String? ?? '',
        description: map['description'] as String? ?? '',
        contributionAmount:
            (map['contributionAmount'] as num?)?.toDouble() ?? 0,
        claimAmount: (map['claimAmount'] as num?)?.toDouble() ?? 0,
        registrationFee: (map['registrationFee'] as num?)?.toDouble() ?? 0,
        isActive: map['isActive'] as bool? ?? true,
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Yojna && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
