import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/core/utils/csv.dart';
import 'package:rudransh_ct/core/utils/validators.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/features/export/export_actions.dart';

import 'support/seed_data.dart';

void main() {
  group('csv', () {
    test('starts with a BOM so Excel reads Hindi as UTF-8', () {
      expect(toCsv([
        ['रमेश'],
      ]).startsWith('﻿'), isTrue);
    });

    test('quotes commas, quotes and line breaks; ends rows in CRLF', () {
      final csv = toCsv([
        ['a,b', 'say "hi"', 'two\nlines', 'plain'],
      ]);
      expect(csv, '﻿"a,b","say ""hi""","two\nlines",plain\r\n');
    });

    test('a cell that looks like a formula is kept as text', () {
      final csv = toCsv([
        ['=SUM(A1)', '+91', '-5', '@x', 'ok'],
      ]);
      expect(csv, "﻿'=SUM(A1),'+91,'-5,'@x,ok\r\n");
    });

    test('null prints as an empty cell', () {
      expect(toCsv([
        [null, 1],
      ]), '﻿,1\r\n');
    });
  });

  group('export rows', () {
    final repo = seededRepository();
    final yojnas = {for (final y in repo.yojnasView) y.id: y};
    final agents = {for (final a in repo.agentsView) a.id: a};

    test('members: a header, one row each, and only the last four Aadhaar',
        () {
      final members = repo.membersView;
      final rows = memberCsvRows(members, yojnas: yojnas, agents: agents);
      expect(rows, hasLength(members.length + 1));
      expect(rows.first.first, 'Reg no');

      final withAadhaar = members.firstWhere((m) => m.aadhaar.length == 12);
      final row = rows.firstWhere((r) => r.first == withAadhaar.regNo);
      final aadhaar = row[rows.first.indexOf('Aadhaar')] as String;
      expect(aadhaar, 'XXXX XXXX ${withAadhaar.aadhaarLast4}');
      expect(rows.expand((r) => r).contains(withAadhaar.aadhaar), isFalse,
          reason: 'the full number never reaches the file');
    });

    test('payments: cancelled receipts stay in, marked Cancelled', () {
      final p = repo.paymentsView.first;
      final cancelled = p.copyWith(cancelledAt: DateTime(2026, 9, 1));
      final rows = paymentCsvRows(
        [p, cancelled],
        members: {
          for (final m in repo.membersView) m.id: MemberRef.of(m),
        },
        yojnas: yojnas,
        agents: agents,
      );
      final status = rows.first.indexOf('Status');
      expect(rows[1][status], p.isCancelled ? 'Cancelled' : p.status.label);
      expect(rows[2][status], 'Cancelled');
      expect(rows[1][rows.first.indexOf('Amount')], p.amount.toStringAsFixed(2));
    });
  });

  group('member email', () {
    test('is optional, but must look like an address when given', () {
      expect(V.optionalEmail(''), isNull);
      expect(V.optionalEmail('  '), isNull);
      expect(V.optionalEmail('ram@example.com'), isNull);
      expect(V.optionalEmail('ram@'), isNotNull);
    });

    test('goes out in the members sheet', () {
      final repo = seededRepository();
      final m = repo.membersView.first.copyWith(email: 'ram@example.com');
      final rows = memberCsvRows([m], yojnas: const {}, agents: const {});
      expect(rows[1][rows.first.indexOf('Email')], 'ram@example.com');
    });
  });
}
