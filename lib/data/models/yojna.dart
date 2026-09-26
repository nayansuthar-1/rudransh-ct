import 'package:flutter/foundation.dart';

import '../../core/utils/devanagari.dart';

/// A scheme / programme (Yojna) run by the trust.
@immutable
class Yojna {
  const Yojna({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.shortName = '',
    this.claimAmount = 0,
    this.registrationFee = 0,
    this.startDate,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;

  /// Display name as the trust writes it.
  final String name;

  /// Short uppercase code used in registration numbers (e.g. `SSY`).
  final String code;
  final String description;

  /// The word the certificate prints in `प्रत्येक <shortName> सहयोग राशि`,
  /// e.g. `शादी`. Empty takes it from [name].
  final String shortName;

  /// This Yojna's सहयोग राशि label on the membership certificate.
  String get contributionLabel =>
      certificateLabel(name: name, shortName: shortName);

  /// The certificate's सहयोग राशि label: `प्रत्येक शादी सहयोग राशि`.
  ///
  /// The word is [shortName], or else [name] without its trailing
  /// `सहयोग योजना`, always in Hindi: Yojnas are often typed in Hinglish
  /// (`Shadi Sahyog Yojana`), and the label must match the Hindi around it.
  /// Plain `सहयोग राशि` when neither gives a word.
  static String certificateLabel({
    required String name,
    String shortName = '',
  }) {
    var word = shortName.trim();
    if (word.isEmpty) {
      word = name.trim();
      while (true) {
        final shorter = word.replaceFirst(_trailingYojnaWord, '').trim();
        if (shorter == word) break;
        word = shorter;
      }
    }
    word = toDevanagari(word);
    return word.isEmpty ? 'सहयोग राशि' : 'प्रत्येक $word सहयोग राशि';
  }

  /// `सहयोग` or `योजना` ending a Yojna name, in Hindi or Hinglish.
  static final _trailingYojnaWord = RegExp(
    r'(?:^|[\s\-]+)(?:योजना|सहयोग|yojana|yojanaa|yojna|yojnaa|yojona|'
    r'sahyog|sahayog|sahyoga|sahayoga|sahiyog|scheme)\.?$',
    caseSensitive: false,
  );

  /// Amount paid out to the nominee on a closing.
  final double claimAmount;
  final double registrationFee;

  /// When the scheme actually opened, printed as `योजना प्रारंभ` on the
  /// membership certificate. Null on older records, which fall back to
  /// [createdAt].
  final DateTime? startDate;
  final bool isActive;
  final DateTime createdAt;

  Yojna copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? shortName,
    double? claimAmount,
    double? registrationFee,
    DateTime? startDate,
    bool clearStartDate = false,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Yojna(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      shortName: shortName ?? this.shortName,
      claimAmount: claimAmount ?? this.claimAmount,
      registrationFee: registrationFee ?? this.registrationFee,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'shortName': shortName,
        'claimAmount': claimAmount,
        'registrationFee': registrationFee,
        'startDate': startDate?.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Yojna.fromMap(Map<String, dynamic> map) => Yojna(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String? ?? '',
        description: map['description'] as String? ?? '',
        shortName: map['shortName'] as String? ?? '',
        claimAmount: (map['claimAmount'] as num?)?.toDouble() ?? 0,
        registrationFee: (map['registrationFee'] as num?)?.toDouble() ?? 0,
        startDate: DateTime.tryParse(map['startDate'] as String? ?? ''),
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
