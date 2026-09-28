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
    this.ageSlabs = const [],
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

  /// Age-based slabs for joining fee and per-event contribution.
  final List<YojnaAgeSlab> ageSlabs;

  /// This Yojna's सहयोग राशि label on the membership certificate.
  String get contributionLabel =>
      certificateLabel(name: name, shortName: shortName);

  /// Default age slabs matching trust documents for Shadi and Suraksha yojnas
  static List<YojnaAgeSlab> defaultSlabsFor(String nameOrCode) {
    final lower = nameOrCode.toLowerCase();
    if (lower.contains('shadi') ||
        lower.contains('shaadi') ||
        lower.contains('mayara') ||
        lower.contains('शादी') ||
        lower.contains('मायरा') ||
        lower.contains('ssy')) {
      return const [
        YojnaAgeSlab(minAge: 0, maxAge: 5, registrationFee: 0, contributionAmount: 50),
        YojnaAgeSlab(minAge: 6, maxAge: 10, registrationFee: 1100, contributionAmount: 100),
        YojnaAgeSlab(minAge: 11, maxAge: 15, registrationFee: 1500, contributionAmount: 200),
        YojnaAgeSlab(minAge: 16, maxAge: 21, registrationFee: 2100, contributionAmount: 300),
        YojnaAgeSlab(minAge: 22, maxAge: 24, registrationFee: 3100, contributionAmount: 400),
      ];
    }
    if (lower.contains('suraksha') ||
        lower.contains('surksha') ||
        lower.contains('सुरक्षा')) {
      return const [
        YojnaAgeSlab(minAge: 25, maxAge: 50, registrationFee: 1100, contributionAmount: 300),
        YojnaAgeSlab(minAge: 51, maxAge: 55, registrationFee: 1500, contributionAmount: 400),
        YojnaAgeSlab(minAge: 56, maxAge: 60, registrationFee: 2100, contributionAmount: 500),
        YojnaAgeSlab(minAge: 61, maxAge: 70, registrationFee: 3100, contributionAmount: 500),
        YojnaAgeSlab(minAge: 71, maxAge: 120, registrationFee: 3500, contributionAmount: 500, label: '70+ Joint'),
      ];
    }
    return const [];
  }

  /// All active slabs for this Yojna, falling back to defaults by scheme name/code.
  List<YojnaAgeSlab> get effectiveSlabs {
    if (ageSlabs.isNotEmpty) return ageSlabs;
    return defaultSlabsFor('$name $code');
  }

  /// Returns the slab matching [age], or null if outside defined range.
  YojnaAgeSlab? findSlabForAge(int age) {
    for (final s in effectiveSlabs) {
      if (s.matchesAge(age)) return s;
    }
    return null;
  }

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
    List<YojnaAgeSlab>? ageSlabs,
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
      ageSlabs: ageSlabs ?? this.ageSlabs,
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
        'ageSlabs': ageSlabs.map((s) => s.toMap()).toList(),
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
        ageSlabs: ((map['ageSlabs'] ?? map['age_slabs']) as List?)
                ?.map((e) =>
                    YojnaAgeSlab.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Yojna && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// A specific age bracket with its registration fee and per-event contribution.
@immutable
class YojnaAgeSlab {
  const YojnaAgeSlab({
    required this.minAge,
    required this.maxAge,
    required this.registrationFee,
    required this.contributionAmount,
    this.label = '',
  });

  final int minAge;
  final int maxAge;
  final double registrationFee;
  final double contributionAmount;
  final String label;

  bool matchesAge(int age) => age >= minAge && age <= maxAge;

  String get displayRange =>
      label.isNotEmpty ? label : (maxAge >= 100 ? '$minAge+' : '$minAge–$maxAge');

  Map<String, dynamic> toMap() => {
        'minAge': minAge,
        'maxAge': maxAge,
        'registrationFee': registrationFee,
        'contributionAmount': contributionAmount,
        'label': label,
      };

  factory YojnaAgeSlab.fromMap(Map<String, dynamic> map) => YojnaAgeSlab(
        minAge: (map['minAge'] ?? map['min_age'] as num?)?.toInt() ?? 0,
        maxAge: (map['maxAge'] ?? map['max_age'] as num?)?.toInt() ?? 100,
        registrationFee:
            (map['registrationFee'] ?? map['registration_fee'] as num?)
                    ?.toDouble() ??
                0,
        contributionAmount:
            (map['contributionAmount'] ?? map['contribution_amount'] as num?)
                    ?.toDouble() ??
                0,
        label: (map['label'] as String?) ?? '',
      );

  YojnaAgeSlab copyWith({
    int? minAge,
    int? maxAge,
    double? registrationFee,
    double? contributionAmount,
    String? label,
  }) =>
      YojnaAgeSlab(
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        registrationFee: registrationFee ?? this.registrationFee,
        contributionAmount: contributionAmount ?? this.contributionAmount,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is YojnaAgeSlab &&
          other.minAge == minAge &&
          other.maxAge == maxAge &&
          other.registrationFee == registrationFee &&
          other.contributionAmount == contributionAmount &&
          other.label == label);

  @override
  int get hashCode => Object.hash(
        minAge,
        maxAge,
        registrationFee,
        contributionAmount,
        label,
      );
}
