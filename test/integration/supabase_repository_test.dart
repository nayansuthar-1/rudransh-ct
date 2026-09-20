// Runs SupabaseTrustRepository against a real PostgREST + Postgres with the
// migrations applied and seeded. Skipped unless these are set:
//
//   POSTGREST_URL            e.g. http://localhost:3900 (bare PostgREST, no /rest/v1)
//   POSTGREST_ADMIN_JWT      JWT whose `sub` has an active owner profile
//   POSTGREST_STRANGER_JWT   JWT for a signed-in user who is not an admin
//
// Expects the seed from supabase/tests/integration_seed.sql on a disposable
// database: the tests create and delete rows.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/supabase_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

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

SupabaseTrustRepository _repoFor(String jwt) => SupabaseTrustRepository(
      SupabaseClient(
        _url!,
        'local-key',
        httpClient: _StripRestPrefix(),
        accessToken: () async => jwt,
      ),
    );

void main() {
  late SupabaseTrustRepository repo;
  late SupabaseTrustRepository stranger;

  setUpAll(() {
    if (_skip != null) return;
    repo = _repoFor(_env['POSTGREST_ADMIN_JWT']!);
    stranger = _repoFor(_env['POSTGREST_STRANGER_JWT']!);
  });

  group('reads past the 1,000-row cap', skip: _skip, () {
    test('member pages report the full total and do not overlap', () async {
      final first = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: 0,
        limit: 20,
      );
      final far = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: 2000,
        limit: 20,
      );
      expect(first.total, 2500);
      expect(first.items, hasLength(20));
      expect(far.items, hasLength(20));
      expect(
        first.items.map((m) => m.id).toSet().intersection(
              far.items.map((m) => m.id).toSet(),
            ),
        isEmpty,
      );
      // Newest joiners first.
      expect(
        first.items.first.joinDate.isBefore(first.items.last.joinDate),
        isFalse,
      );
    });

    test('a page past the end is empty but keeps the total', () async {
      final page = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: 5000,
        limit: 20,
      );
      expect(page.items, isEmpty);
      expect(page.total, 2500);
    });

    test('filters by scheme, status, district and Hindi text', () async {
      final yojnas = await repo.fetchYojnas();
      final psy = yojnas.firstWhere((y) => y.code == 'PSY');

      final byScheme = await repo.fetchMembersPage(
        MemberQuery(yojnaId: psy.id),
        offset: 0,
        limit: 5,
      );
      expect(byScheme.total, 625);

      final closed = await repo.fetchMembersPage(
        const MemberQuery(status: MemberStatus.closed),
        offset: 0,
        limit: 50,
      );
      expect(closed.total, 5);

      final district = await repo.fetchMembersPage(
        const MemberQuery(district: 'बाड़मेर'),
        offset: 0,
        limit: 5,
      );
      expect(district.total, 833);

      final text = await repo.fetchMembersPage(
        const MemberQuery(text: 'सदस्य 25'),
        offset: 0,
        limit: 50,
      );
      // 25, 250–259 and 2500.
      expect(text.total, 12);
      expect(text.items.every((m) => m.name.startsWith('सदस्य 25')), isTrue);
    });

    test('member search and lookup by ids', () async {
      final closed = await repo.fetchMembersPage(
        const MemberQuery(status: MemberStatus.closed),
        offset: 0,
        limit: 1,
      );
      final target = closed.items.single;

      final withClosed = await repo.searchMembers(target.regNo);
      final withoutClosed =
          await repo.searchMembers(target.regNo, excludeClosed: true);
      expect(withClosed.map((m) => m.id), contains(target.id));
      expect(withoutClosed.map((m) => m.id), isNot(contains(target.id)));

      final page = await repo.fetchMembersPage(
        const MemberQuery(),
        offset: 0,
        limit: 250,
      );
      final byIds = await repo.fetchMembersByIds(page.items.map((m) => m.id));
      expect(byIds, hasLength(250));

      expect(await repo.fetchMemberDistricts(), ['जोधपुर', 'बाड़मेर']..sort());
    });

    test('payment pages embed members and totals cover every row', () async {
      final page = await repo.fetchPaymentsPage(
        const PaymentQuery(),
        offset: 1500,
        limit: 20,
      );
      expect(page.total, greaterThanOrEqualTo(2500));
      expect(page.items, hasLength(20));
      for (final p in page.items) {
        expect(page.members[p.memberId]?.name, startsWith('सदस्य'));
      }

      final totals = await repo.fetchPaymentTotals(const PaymentQuery());
      expect(totals.count, page.total);
      expect(totals.paid + totals.pending + totals.failed,
          closeTo(totals.count * 100.0, 0.001));

      final member = page.items.first.memberId;
      final forMember = await repo.fetchPaymentsPage(
        PaymentQuery(memberId: member),
        offset: 0,
        limit: 10,
      );
      expect(forMember.items.every((p) => p.memberId == member), isTrue);

      final byName = await repo.fetchPaymentsPage(
        PaymentQuery(text: page.members[member]!.regNo),
        offset: 0,
        limit: 10,
      );
      expect(byName.items.map((p) => p.memberId), contains(member));
    });

    test('dashboard aggregates', () async {
      final stats = await repo.fetchDashboardStats(null);
      expect(stats.totalMembers, 2500);
      expect(stats.closedMembers, 5);
      expect(stats.totalAgents, greaterThanOrEqualTo(2));
      expect(stats.pendingClaims, closeTo(5 * 75000.0, 0.001));

      final perYojna = await repo.fetchMembersPerYojna();
      expect(perYojna.values.fold<int>(0, (a, b) => a + b), 2500);

      final perAgent = await repo.fetchMemberCountByAgent();
      expect(perAgent.values.fold<int>(0, (a, b) => a + b), 2500);

      final byAgent = await repo.fetchCollectionByAgent();
      final paid = await repo.fetchPaymentTotals(
        const PaymentQuery(status: PaymentStatus.paid),
      );
      expect(byAgent.values.fold<double>(0, (a, b) => a + b),
          closeTo(paid.paid, 0.001));
    });
  });

  group('writes', skip: _skip, () {
    test('numbers come from the database and match the preview', () async {
      final ssy = (await repo.fetchYojnas()).firstWhere((y) => y.code == 'SSY');

      final previewReg = await repo.nextRegNo(ssy.id);
      final member = await repo.createMember(
        Member(
          id: '',
          yojnaId: ssy.id,
          regNo: 'IGNORED',
          name: 'एकीकरण परीक्षण',
          fatherOrHusbandName: 'पिता',
          jati: 'सुथार',
          warisName: 'वारिस',
          warisRelation: 'पुत्र',
          primaryPhone: '9111111111',
          aadhaar: '',
          joinDate: DateTime(2026, 9, 14),
        ),
      );
      expect(member.regNo, previewReg);
      expect(member.joinDate, DateTime(2026, 9, 14));

      final previewReceipt = await repo.nextReceiptNo();
      await repo.createPayment(
        Payment(
          id: '',
          receiptNo: 'IGNORED',
          memberId: member.id,
          yojnaId: ssy.id,
          amount: 250,
          date: DateTime(2026, 9, 14),
          mode: PaymentMode.upi,
          reference: 'UTR123',
        ),
      );
      final receipts = await repo.fetchPaymentsPage(
        PaymentQuery(memberId: member.id),
        offset: 0,
        limit: 5,
      );
      expect(receipts.items.single.receiptNo, previewReceipt);
      expect(receipts.items.single.mode, PaymentMode.upi);

      final previewCode = await repo.nextAgentCode();
      final agent = await repo.createAgent(
        Agent(
          id: '',
          code: 'IGNORED',
          name: 'नया एजेंट',
          phone: '9222222222',
          yojnaIds: [ssy.id],
          joinDate: DateTime(2026, 9, 14),
        ),
      );
      expect(agent.code, previewCode);
      expect(agent.yojnaIds, [ssy.id]);

      final edited = await repo.updateMember(
        member.copyWith(village: 'बालोतरा', agentId: agent.id),
      );
      expect(edited.village, 'बालोतरा');
      expect(edited.regNo, member.regNo);

      // Receipts block the delete, with a message the admin can act on.
      await expectLater(
        repo.deleteMember(member.id),
        throwsA(
          isA<RepositoryException>()
              .having((e) => e.message, 'message', contains('Inactive')),
        ),
      );

      // Deleting the agent unassigns the member.
      await repo.deleteAgent(agent.id);
      final after = await repo.fetchMembersByIds([member.id]);
      expect(after.single.agentId, isNull);
    });

    test('closing case closes and reopens the member', () async {
      final page = await repo.fetchMembersPage(
        const MemberQuery(status: MemberStatus.active),
        offset: 0,
        limit: 1,
      );
      final member = page.items.single;

      final created = await repo.createClosingCase(
        ClosingCase(
          id: '',
          memberId: member.id,
          yojnaId: member.yojnaId,
          closingDate: DateTime(2026, 9, 10),
          closingGroup: 'Group-IT',
          claimAmount: 100000,
        ),
      );
      var reread = (await repo.fetchMembersByIds([member.id])).single;
      expect(reread.status, MemberStatus.closed);
      expect(reread.closingGroup, 'Group-IT');

      await expectLater(
        repo.createClosingCase(created.copyWith(id: '')),
        throwsA(isA<RepositoryException>()),
      );

      await repo.deleteClosingCase(created.id);
      reread = (await repo.fetchMembersByIds([member.id])).single;
      expect(reread.status, MemberStatus.active);
      expect(reread.closingDate, isNull);
    });

    test('duplicate scheme code is explained', () async {
      await expectLater(
        repo.createYojna(
          Yojna(id: '', name: 'Dup', code: 'SSY', createdAt: DateTime.now()),
        ),
        throwsA(
          isA<RepositoryException>()
              .having((e) => e.message, 'message', contains('Yojna code')),
        ),
      );
    });
  });

  group('non-admin', skip: _skip, () {
    test('sees nothing and cannot write', () async {
      final page = await stranger.fetchMembersPage(
        const MemberQuery(),
        offset: 0,
        limit: 20,
      );
      expect(page.total, 0);
      expect((await stranger.fetchDashboardStats(null)).totalMembers, 0);

      await expectLater(
        stranger.createYojna(
          Yojna(id: '', name: 'Hack', code: 'HACK', createdAt: DateTime.now()),
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  // A logged-out browser sends no JWT, so PostgREST runs as `anon`.
  group('logged out', skip: _skip, () {
    test('cannot read any table or call any function', () async {
      Future<void> expectDenied(http.Response res, String what) async {
        expect(res.statusCode, anyOf(401, 403), reason: '$what: ${res.body}');
        expect(res.body, contains('42501'), reason: what);
      }

      for (final table in [
        'yojnas', 'agents', 'members', 'payments', 'closing_cases',
        'admins', 'counters', 'audit_log',
      ]) {
        await expectDenied(
          await http.get(Uri.parse('$_url/$table?select=*&limit=1')),
          'GET $table',
        );
      }
      await expectDenied(
        await http.post(
          Uri.parse('$_url/rpc/dashboard_stats'),
          headers: {'Content-Type': 'application/json'},
          body: '{}',
        ),
        'rpc dashboard_stats',
      );
      await expectDenied(
        await http.post(
          Uri.parse('$_url/yojnas'),
          headers: {'Content-Type': 'application/json'},
          body: '{"name":"Hack","code":"HACK"}',
        ),
        'POST yojnas',
      );
    });
  });
}
