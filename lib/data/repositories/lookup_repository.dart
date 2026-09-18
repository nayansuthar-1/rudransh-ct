import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'trust_repository.dart' show RepositoryException;

/// The public membership lookup (IMPLEMENTATION_PLAN Phase 15).
///
/// Signed out by definition, so it never touches the database directly: the
/// `member_lookup` Edge Function checks Cloudflare Turnstile first and is the
/// only caller of the database function.
abstract class LookupRepository {
  /// Returns null when nothing matches. A wrong guess still counts towards
  /// the lock, so the caller should not retry automatically.
  Future<MemberLookup?> find({
    required String regNo,
    required String phone,
    required String aadhaar4,
    required String turnstileToken,
  });
}

class EdgeLookupRepository implements LookupRepository {
  EdgeLookupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MemberLookup?> find({
    required String regNo,
    required String phone,
    required String aadhaar4,
    required String turnstileToken,
  }) async {
    try {
      final res = await _client.functions.invoke('member_lookup', body: {
        'reg_no': regNo,
        'phone': phone,
        'aadhaar4': aadhaar4,
        'turnstile_token': turnstileToken,
      });
      final data = res.data;
      if (data is! Map) {
        throw const RepositoryException('Could not check the records. Try again.');
      }
      if (data['found'] != true) return null;
      return MemberLookup.fromRow(
        Map<String, dynamic>.from(data['member'] as Map),
      );
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
  InMemoryLookupRepository(this._members, this._yojnas, this._dues);

  final List<Member> Function() _members;
  final List<Yojna> Function() _yojnas;
  final List<MemberDue> Function() _dues;

  final _failures = <String, List<DateTime>>{};

  @override
  Future<MemberLookup?> find({
    required String regNo,
    required String phone,
    required String aadhaar4,
    required String turnstileToken,
  }) async {
    final reg = regNo.trim().toUpperCase();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final last4 = aadhaar4.replaceAll(RegExp(r'\D'), '');
    if (reg.isEmpty || digits.isEmpty) {
      throw const RepositoryException(
        'Enter the registration number and phone number.',
      );
    }
    if (_locked(reg)) {
      throw const RepositoryException(
        'Too many wrong tries. Try again after 15 minutes.',
      );
    }

    final match = _members().where((m) {
      if (m.regNo.toUpperCase() != reg) return false;
      if (m.primaryPhone != digits && m.altPhone != digits) return false;
      // Aadhaar is optional on a member record; when it is absent the
      // registration number and phone are the whole check.
      if (m.aadhaar.isEmpty) return true;
      return m.aadhaar.length >= 4 &&
          m.aadhaar.substring(m.aadhaar.length - 4) == last4;
    }).firstOrNull;

    if (match == null) {
      _failures.putIfAbsent(reg, () => []).add(DateTime.now());
      return null;
    }

    final yojna = _yojnas().firstWhere((y) => y.id == match.yojnaId);
    final owed = _dues().where((d) => d.memberId == match.id && d.due > 0);
    return MemberLookup(
      regNo: match.regNo,
      name: match.name,
      yojnaName: yojna.name,
      status: match.status,
      joinDate: match.joinDate,
      contributionAmount: yojna.contributionAmount,
      duesCount: owed.length,
      duesAmount: owed.fold<double>(0, (sum, d) => sum + d.due),
    );
  }

  bool _locked(String reg) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    final recent =
        (_failures[reg] ?? const []).where((t) => t.isAfter(cutoff)).toList();
    _failures[reg] = recent;
    return recent.length >= 5;
  }
}
