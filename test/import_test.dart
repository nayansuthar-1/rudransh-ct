import 'package:flutter_test/flutter_test.dart';

import '../tool/import/csv_import.dart';

void main() {
  group('parseCsv', () {
    test('handles BOM, quotes, commas and newlines inside quotes', () {
      final rows = parseCsv(
        '﻿name,note\r\n"गीता, देवी","line one\nline ""two"""\r\n\r\n',
      );
      expect(rows, [
        ['name', 'note'],
        ['गीता, देवी', 'line one\nline "two"'],
      ]);
    });

    test('round-trips through toCsv', () {
      final rows = [
        ['a,b', 'say "hi"', 'plain'],
      ];
      expect(parseCsv(toCsv(rows)), rows);
    });
  });

  group('normalizeDate', () {
    test('accepts Indian and ISO formats', () {
      expect(normalizeDate('05-04-2025'), '2025-04-05');
      expect(normalizeDate('5/4/2025'), '2025-04-05');
      expect(normalizeDate('2025-04-05'), '2025-04-05');
    });

    test('rejects impossible and future dates', () {
      expect(normalizeDate('31-02-2025'), isNull);
      expect(normalizeDate('01-01-2999'), isNull);
      expect(normalizeDate('April 5'), isNull);
    });
  });

  group('validateImport', () {
    test('normalizes values Excel users typically enter', () {
      final r = validateImport(
        membersCsv: parseCsv(
          'reg_no,yojna_code,name,gender,primary_phone,aadhaar,status\n'
          'ssy-2025-0001,ssy,गीता,महिला,+91 98765 43210,1234 5678 9012,बंद\n',
        ),
        paymentsCsv: parseCsv(
          'reg_no,amount,date,mode\n'
          'SSY-2025-0001,"₹1,500",15/05/2025,NEFT\n',
        ),
      );
      expect(r.problems, isEmpty);
      final m = r.members.single;
      expect(m['reg_no'], 'SSY-2025-0001');
      expect(m['yojna_code'], 'SSY');
      expect(m['gender'], 'female');
      expect(m['primary_phone'], '9876543210');
      expect(m['aadhaar'], '123456789012');
      expect(m['status'], 'closed');
      final p = r.payments.single;
      expect(p['amount'], '1500.00');
      expect(p['date'], '2025-05-15');
      expect(p['mode'], 'bank');
      expect(r.paymentTotal, 1500);
    });

    test('reports bad rows with line numbers and keeps good ones', () {
      final r = validateImport(
        membersCsv: parseCsv(
          'reg_no,yojna_code,name,primary_phone,pincode\n'
          'SSY-2025-0001,SSY,एक,9876543210,344022\n'
          'SSY-2025-0002,SSY,दो,98765,\n'
          'SSY-2025-0001,SSY,तीन,9876543211,\n'
          'SSY-2025-0004,SSY,,9876543212,1234\n',
        ),
      );
      expect(r.members.map((m) => m['name']), ['एक']);
      expect(
        r.problems.map((p) => '${p.line}:${p.column}'),
        ['3:primary_phone', '4:reg_no', '5:name', '5:pincode'],
      );
      expect(r.problems[1].message, contains('duplicate of line 2'));
    });

    test('holds back payments of rejected members', () {
      final r = validateImport(
        membersCsv: parseCsv(
          'reg_no,yojna_code,name,primary_phone\n'
          'SSY-2025-0001,SSY,एक,123\n',
        ),
        paymentsCsv: parseCsv(
          'reg_no,amount,date\n'
          'SSY-2025-0001,100,01-05-2025\n'
          'SSY-2020-0009,100,01-05-2025\n',
        ),
      );
      // The second payment may belong to a member already in the database.
      expect(r.payments.map((p) => p['reg_no']), ['SSY-2020-0009']);
      expect(r.problems.last.message, contains('member row was rejected'));
    });

    test('a missing required column rejects the whole file', () {
      final r = validateImport(
        membersCsv: parseCsv('reg_no,name\nSSY-2025-0001,एक\n'),
      );
      expect(r.members, isEmpty);
      expect(
        r.problems.map((p) => p.column),
        containsAll(['yojna_code', 'primary_phone']),
      );
    });
  });

  group('buildSql', () {
    test('is one transaction that inserts numbered rows before blank ones',
        () {
      final r = validateImport(
        agentsCsv: parseCsv('code,name\n,नया\nAG-005,पुराना\n'),
        membersCsv: parseCsv(
          'reg_no,yojna_code,name,primary_phone\n'
          ",SSY,O'Brien,9876543210\n",
        ),
      );
      final sql = buildSql(r);

      expect(sql, contains('begin;'));
      expect(sql.trimRight(), endsWith('commit;'));
      expect(sql, contains("'O''Brien'"));
      expect(sql, contains('These agent codes already exist'));

      final numbered = sql.indexOf("('AG-005'");
      final blank = sql.indexOf("'नया'");
      expect(numbered, greaterThan(0));
      expect(numbered, lessThan(blank));
      expect(
        sql.substring(numbered, blank),
        contains('insert into public.counters'),
      );
    });
  });
}
