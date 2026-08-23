import 'package:flutter/foundation.dart';

enum ClosingPayStatus {
  unpaid('Unpaid'),
  partial('Partial'),
  paid('Paid');

  const ClosingPayStatus(this.label);
  final String label;

  static ClosingPayStatus fromName(String? value) => ClosingPayStatus.values
      .firstWhere((s) => s.name == value, orElse: () => ClosingPayStatus.unpaid);
}

/// A settled / closing membership — the "Closed Cases" table on the dashboard.
@immutable
class ClosingCase {
  const ClosingCase({
    required this.id,
    required this.memberId,
    required this.yojnaId,
    required this.closingDate,
    required this.closingGroup,
    required this.claimAmount,
    this.collectedAmount = 0,
    this.payStatus = ClosingPayStatus.unpaid,
    this.nomineeName = '',
    this.remarks = '',
  });

  final String id;
  final String memberId;
  final String yojnaId;
  final DateTime closingDate;

  /// Batch label, e.g. `Group-14`.
  final String closingGroup;

  /// Total payable to the nominee.
  final double claimAmount;

  /// Contribution collected from members so far for this case.
  final double collectedAmount;
  final ClosingPayStatus payStatus;
  final String nomineeName;
  final String remarks;

  double get pendingAmount =>
      (claimAmount - collectedAmount).clamp(0, double.infinity);

  double get progress =>
      claimAmount <= 0 ? 0 : (collectedAmount / claimAmount).clamp(0, 1);

  ClosingCase copyWith({
    String? id,
    String? memberId,
    String? yojnaId,
    DateTime? closingDate,
    String? closingGroup,
    double? claimAmount,
    double? collectedAmount,
    ClosingPayStatus? payStatus,
    String? nomineeName,
    String? remarks,
  }) {
    return ClosingCase(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      yojnaId: yojnaId ?? this.yojnaId,
      closingDate: closingDate ?? this.closingDate,
      closingGroup: closingGroup ?? this.closingGroup,
      claimAmount: claimAmount ?? this.claimAmount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      payStatus: payStatus ?? this.payStatus,
      nomineeName: nomineeName ?? this.nomineeName,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'memberId': memberId,
        'yojnaId': yojnaId,
        'closingDate': closingDate.toIso8601String(),
        'closingGroup': closingGroup,
        'claimAmount': claimAmount,
        'collectedAmount': collectedAmount,
        'payStatus': payStatus.name,
        'nomineeName': nomineeName,
        'remarks': remarks,
      };

  factory ClosingCase.fromMap(Map<String, dynamic> map) => ClosingCase(
        id: map['id'] as String,
        memberId: map['memberId'] as String,
        yojnaId: map['yojnaId'] as String,
        closingDate:
            DateTime.tryParse(map['closingDate'] as String? ?? '') ??
                DateTime.now(),
        closingGroup: map['closingGroup'] as String? ?? '',
        claimAmount: (map['claimAmount'] as num?)?.toDouble() ?? 0,
        collectedAmount: (map['collectedAmount'] as num?)?.toDouble() ?? 0,
        payStatus: ClosingPayStatus.fromName(map['payStatus'] as String?),
        nomineeName: map['nomineeName'] as String? ?? '',
        remarks: map['remarks'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ClosingCase && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
