import 'package:flutter/foundation.dart';

/// Why a notification was written (the `type` column). Anything the database
/// sends that this app does not know about falls back to [other], so an older
/// build keeps working after a new trigger is added.
enum NotificationKind {
  paymentApproved('payment_approved'),
  paymentRejected('payment_rejected'),
  closingApproved('closing_approved'),
  closingRejected('closing_rejected'),
  closingNew('closing_new'),
  memberAssigned('member_assigned'),
  memberRemoved('member_removed'),
  duesOverdue('dues_overdue'),
  handoverConfirmed('handover_confirmed'),
  handoverRejected('handover_rejected'),
  commissionPaid('commission_paid'),
  other('');

  const NotificationKind(this.code);
  final String code;

  static NotificationKind of(String code) => values.firstWhere(
        (k) => k.code == code,
        orElse: () => NotificationKind.other,
      );

  /// Good news, bad news, or neither: decides the dot colour in the panel.
  bool get isBad =>
      this == NotificationKind.paymentRejected ||
      this == NotificationKind.closingRejected ||
      this == NotificationKind.handoverRejected ||
      this == NotificationKind.duesOverdue;

  bool get isGood =>
      this == NotificationKind.paymentApproved ||
      this == NotificationKind.handoverConfirmed ||
      this == NotificationKind.commissionPaid ||
      this == NotificationKind.closingApproved;
}

/// One line in the notification panel (IMPLEMENTATION_PLAN Phase 14).
///
/// Written by database triggers, never by the app; the app only reads them
/// and marks them read.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.link = '',
    this.readAt,
  });

  final int id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// In-app route to open, e.g. `/agent/collections`. Empty means no target.
  final String link;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        link: link,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );

  static AppNotification fromRow(Map<String, dynamic> r) => AppNotification(
        id: (r['id'] as num).toInt(),
        kind: NotificationKind.of((r['type'] ?? '') as String),
        title: (r['title'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        link: (r['link'] ?? '') as String,
        readAt: r['read_at'] == null
            ? null
            : DateTime.parse(r['read_at'] as String).toLocal(),
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

/// A notice the office posts for everyone, or for one Yojna.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.publishedAt,
    this.body = '',
    this.yojnaId,
    this.yojnaName = '',
  });

  final String id;
  final String title;
  final String body;

  /// Null means every Yojna.
  final String? yojnaId;
  final String yojnaName;
  final DateTime publishedAt;

  bool get isForEveryone => yojnaId == null;

  static Announcement fromRow(Map<String, dynamic> r) => Announcement(
        id: r['id'] as String,
        title: (r['title'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        yojnaId: r['yojna_id'] as String?,
        yojnaName: (r['yojna_name'] ?? '') as String,
        publishedAt: DateTime.parse(r['published_at'] as String).toLocal(),
      );
}
