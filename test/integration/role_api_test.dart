// Phase 17 access sweep: every door, tried as every role, through PostgREST
// rather than the UI. Hiding a screen is not access control — this is the test
// that proves the database refuses.
//
// Skipped unless these are set:
//
//   POSTGREST_URL            e.g. http://localhost:3900 (bare PostgREST)
//   POSTGREST_ADMIN_JWT      an active owner
//   POSTGREST_AGENT_JWT      Agent One
//   POSTGREST_AGENT2_JWT     Agent Two
//   POSTGREST_MEMBER_JWT     a member belonging to Agent One
//   POSTGREST_STRANGER_JWT   signed in, no profile at all
//
// Expects supabase/tests/integration_seed.sql on a disposable database.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final _env = Platform.environment;
final _url = _env['POSTGREST_URL'];
final _skip = _url == null ? 'POSTGREST_URL not set' : null;

/// Supabase serves PostgREST under /rest/v1; a bare PostgREST serves at root.
class _StripRestPrefix extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final uri = request.url.replace(
      path: request.url.path.replaceFirst('/rest/v1', ''),
    );
    final copy = http.StreamedRequest(request.method, uri)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..contentLength = request.contentLength;
    request.finalize().listen(
          copy.sink.add,
          onError: copy.sink.addError,
          onDone: copy.sink.close,
        );
    return _inner.send(copy);
  }
}

/// A client for one role. [jwt] null means signed out (`anon`).
SupabaseClient _clientFor(String? jwt) => SupabaseClient(
      _url!,
      'local-key',
      httpClient: _StripRestPrefix(),
      accessToken: jwt == null ? null : () async => jwt,
    );

/// Every table an admin works with. None of them has a policy for agents or
/// members, so a direct read must come back with nothing.
const _tables = [
  'members',
  'payments',
  'agents',
  'yojnas',
  'closing_cases',
  'profiles',
  'cash_handovers',
  'commission_payouts',
  'closing_requests',
  'change_requests',
  'announcements',
  'audit_log',
  'lookup_attempts',
];

/// Reads a table directly and reports what happened: the row count, or null
/// when the request was refused outright. Both are acceptable answers for a
/// role that should see nothing; returning rows is not.
Future<int?> _tryRead(SupabaseClient db, String table) async {
  try {
    final rows = await db.from(table).select().limit(5);
    return rows.length;
  } on PostgrestException {
    return null;
  }
}

/// Calls an RPC and returns the error code, or null when it succeeded.
Future<String?> _tryRpc(
  SupabaseClient db,
  String name, [
  Map<String, dynamic>? params,
]) async {
  try {
    await db.rpc(name, params: params);
    return null;
  } on PostgrestException catch (e) {
    return e.code ?? 'error';
  }
}

void main() {
  late SupabaseClient admin;
  late SupabaseClient agent;
  late SupabaseClient agent2;
  late SupabaseClient member;
  late SupabaseClient stranger;
  late SupabaseClient anon;

  setUpAll(() {
    if (_skip != null) return;
    admin = _clientFor(_env['POSTGREST_ADMIN_JWT']);
    agent = _clientFor(_env['POSTGREST_AGENT_JWT']);
    agent2 = _clientFor(_env['POSTGREST_AGENT2_JWT']);
    member = _clientFor(_env['POSTGREST_MEMBER_JWT']);
    stranger = _clientFor(_env['POSTGREST_STRANGER_JWT']);
    anon = _clientFor(null);
  });

  group('direct table reads', skip: _skip, () {
    test('an owner reads the tables they work with', () async {
      // The control: if this fails the sweep below proves nothing, because
      // everything would look "denied".
      for (final table in ['members', 'payments', 'agents', 'yojnas']) {
        expect(
          await _tryRead(admin, table),
          greaterThan(0),
          reason: 'an owner should read $table',
        );
      }
    });

    for (final (label, who) in [
      ('an agent', () => agent),
      ('a member', () => member),
      ('a signed-in user with no profile', () => stranger),
      ('a signed-out visitor', () => anon),
    ]) {
      test('$label reads nothing from any table', () async {
        final leaked = <String>[];
        for (final table in _tables) {
          final rows = await _tryRead(who(), table);
          if (rows != null && rows > 0) leaked.add('$table ($rows rows)');
        }
        expect(leaked, isEmpty, reason: '$label could read: $leaked');
      });
    }
  });

  group('agents reach their own members only', skip: _skip, () {
    test('and never another agent\'s', () async {
      final mine = (await agent.rpc('agent_members') as List)
          .map((r) => (r as Map)['id'] as String)
          .toSet();
      final theirs = (await agent2.rpc('agent_members') as List)
          .map((r) => (r as Map)['id'] as String)
          .toSet();

      expect(mine, isNotEmpty, reason: 'Agent One has members in the seed');
      expect(theirs, isNotEmpty, reason: 'Agent Two has members in the seed');
      expect(
        mine.intersection(theirs),
        isEmpty,
        reason: 'no member belongs to both agents',
      );
    });

    test('Aadhaar never leaves the office', () async {
      final rows = await agent.rpc('agent_members') as List;
      final first = rows.first as Map;
      expect(first.containsKey('aadhaar'), isFalse);
      // The masked column is the only one an agent may see.
      expect(first.containsKey('aadhaar_last4'), isTrue);
    });

    test('an agent cannot call admin or owner functions', () async {
      for (final (name, params) in [
        ('pending_handovers', null),
        ('commission_report', <String, dynamic>{'p_month': '2026-09-01'}),
        ('pending_change_requests', null),
        ('approve_member', <String, dynamic>{
          'p_member_id': '00000000-0000-0000-0000-000000000001',
        }),
        (
          'mark_commission_paid',
          <String, dynamic>{
            'p_agent_id': '00000000-0000-0000-0000-000000000001',
            'p_month': '2026-09-01',
            'p_amount': 1,
            'p_reference': 'x',
          }
        ),
      ]) {
        expect(
          await _tryRpc(agent, name, params),
          isNotNull,
          reason: 'an agent got through to $name',
        );
      }
    });

    test('an agent sees their own cash and commission', () async {
      // Proves the refusals above are about permission, not a broken setup.
      expect(await _tryRpc(agent, 'agent_summary'), isNull);
      expect(await _tryRpc(agent, 'agent_open_cash'), isNull);
      expect(
        await _tryRpc(agent, 'agent_commission', {'p_months': 3}),
        isNull,
      );
    });
  });

  group('members reach their own record only', skip: _skip, () {
    test('my_membership returns exactly one row, and it is theirs', () async {
      final rows = await member.rpc('my_membership') as List;
      expect(rows, hasLength(1));
      final mine = (rows.first as Map)['member_id'] as String;

      // The same member must not be reachable as anyone else's.
      final agentTwoSees = (await agent2.rpc('agent_members') as List)
          .map((r) => (r as Map)['id'] as String);
      expect(agentTwoSees, isNot(contains(mine)));
    });

    test('a member cannot call agent or admin functions', () async {
      for (final name in [
        'agent_members',
        'agent_summary',
        'agent_open_cash',
        'pending_handovers',
        'pending_change_requests',
      ]) {
        expect(
          await _tryRpc(member, name),
          isNotNull,
          reason: 'a member got through to $name',
        );
      }
    });
  });

  group('the signed-out door', skip: _skip, () {
    test('the public lookup is not reachable without the Edge Function',
        () async {
      // `member_lookup` is granted to service_role only; the Edge Function
      // checks Turnstile and calls it. A stolen publishable key gets nothing.
      expect(
        await _tryRpc(anon, 'member_lookup', {
          'p_reg_no': 'SSY-2026-0001',
          'p_phone': '9000000001',
          'p_aadhaar4': '',
        }),
        isNotNull,
      );
    });

    test('nor is anything else', () async {
      for (final name in [
        'agent_members',
        'agent_summary',
        'my_membership',
        'commission_report',
        'pending_handovers',
        'dashboard_stats',
      ]) {
        expect(
          await _tryRpc(anon, name),
          isNotNull,
          reason: 'anon got through to $name',
        );
      }
    });
  });
}
