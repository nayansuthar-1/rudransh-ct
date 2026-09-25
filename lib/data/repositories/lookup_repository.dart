import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'trust_repository.dart' show RepositoryException;

/// The public membership lookup (IMPLEMENTATION_PLAN Phase 15).
///
/// Signed out by definition, so it never touches the database directly: the
/// `member_lookup` Edge Function checks Cloudflare Turnstile first and is the
/// only caller of the database function.
abstract class LookupRepository {
  /// Every membership held under [phone] whose Aadhaar ends in [aadhaar4] —
  /// one person may be in more than one Yojna. Empty when nothing matches. A
  /// wrong guess still counts towards the lock, so the caller should not
  /// retry automatically.
  Future<List<MemberLookup>> find({
    required String phone,
    required String aadhaar4,
    required String turnstileToken,
  });
}

class EdgeLookupRepository implements LookupRepository {
  EdgeLookupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MemberLookup>> find({
    required String phone,
    required String aadhaar4,
    required String turnstileToken,
  }) async {
    try {
      final res = await _client.functions.invoke('member_lookup', body: {
        'phone': phone,
        'aadhaar4': aadhaar4,
        'turnstile_token': turnstileToken,
      });
      final data = res.data;
      if (data is! Map) {
        throw const RepositoryException('Could not check the records. Try again.');
      }
      if (data['found'] != true) return const [];
      final rows = data['members'] as List? ?? [data['member']];
      return [
        for (final r in rows)
          MemberLookup.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw RepositoryException(
        message ?? 'Could not check the records (${e.status}). Try again later.',
      );
    }
  }
}

/// Demo mode and widget tests: matches against the in-memory records with the
/// same rules as the database function, including the five-try lock.
class InMemoryLookupRepository implements LookupRepository {
  InMemoryLookupRepository(
    this._members,
    this._yojnas,
    this._dues, {
    List<Payment> Function()? payments,
    List<Agent> Function()? agents,
  })  : _payments = payments ?? (() => const []),
        _agents = agents ?? (() => const []);

  final List<Member> Function() _members;
  final List<Yojna> Function() _yojnas;
  final List<MemberDue> Function() _dues;
  final List<Payment> Function() _payments;
  final List<Agent> Function() _agents;

  final _failures = <String, List<DateTime>>{};

  @override
  Future<List<MemberLookup>> find({
    required String phone,
    required String aadhaar4,
    required String turnstileToken,
  }) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final last4 = aadhaar4.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      throw const RepositoryException('Enter the 10-digit phone number.');
    }
    if (last4.length != 4) {
      throw const RepositoryException(
        'Enter the last 4 digits of your Aadhaar.',
      );
    }
    if (_locked(digits)) {
      throw const RepositoryException(
        'Too many wrong tries. Try again after 15 minutes.',
      );
    }

    // A member with no Aadhaar on record never matches: the phone alone is
    // not enough to show anyone's standing.
    final matches = _members().where((m) {
      if (m.primaryPhone != digits && m.altPhone != digits) return false;
      return m.aadhaar.length >= 4 &&
          m.aadhaar.substring(m.aadhaar.length - 4) == last4;
    }).toList()
      ..sort((a, b) => a.joinDate.compareTo(b.joinDate));

    if (matches.isEmpty) {
      _failures.putIfAbsent(digits, () => []).add(DateTime.now());
      return const [];
    }

    return [
      for (final m in matches) _summary(m),
    ];
  }

  MemberLookup _summary(Member m) {
    final yojna = _yojnas().firstWhere((y) => y.id == m.yojnaId);
    final owed = _dues().where((d) => d.memberId == m.id && d.due > 0);
    final agent = _agents().where((a) => a.id == m.agentId).firstOrNull;
    final receipts = _payments()
        .where((p) =>
            p.memberId == m.id &&
            p.status == PaymentStatus.paid &&
            !p.isCancelled)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return MemberLookup(
      regNo: m.regNo,
      name: m.name,
      yojnaName: yojna.name,
      status: m.status,
      joinDate: m.joinDate,
      contributionAmount: m.contributionAmount,
      duesCount: owed.length,
      duesAmount: owed.fold<double>(0, (sum, d) => sum + d.due),
      // As the database function: the member without their Aadhaar.
      member: m.copyWith(aadhaar: ''),
      payoutNote: yojna.description,
      yojnaStartedOn: yojna.startDate ?? yojna.createdAt,
      yojnaShortName: yojna.shortName,
      agentName: agent?.name ?? '',
      receipts: receipts,
    );
  }

  bool _locked(String phone) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    final recent =
        (_failures[phone] ?? const []).where((t) => t.isAfter(cutoff)).toList();
    _failures[phone] = recent;
    return recent.length >= 5;
  }
}
