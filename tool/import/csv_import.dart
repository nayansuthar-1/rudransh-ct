/// Validates the trust's existing records (CSV exported from Excel) and turns
/// the valid rows into one SQL transaction. Pure Dart so it runs as a CLI and
/// in unit tests. Column reference: `tool/import/README.md`.
library;

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

/// RFC 4180 CSV: quoted fields, doubled quotes, commas and newlines in quotes.
/// Strips the UTF-8 byte-order mark Excel adds.
List<List<String>> parseCsv(String input) {
  final text = input.startsWith('﻿') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    if (!(row.length == 1 && row.first.trim().isEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      endField();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String toCsv(List<List<String>> rows) => rows
    .map((r) => r.map((v) {
          final needsQuotes = v.contains(RegExp(r'[",\r\n]'));
          return needsQuotes ? '"${v.replaceAll('"', '""')}"' : v;
        }).join(','))
    .join('\r\n');

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

class Problem {
  const Problem(this.file, this.line, this.column, this.value, this.message);

  final String file;

  /// 1-based line in the CSV, header included, as Excel shows it.
  final int line;
  final String column;
  final String value;
  final String message;

  List<String> toRow() => [file, '$line', column, value, message];
}

class ImportResult {
  ImportResult({
    required this.agents,
    required this.members,
    required this.payments,
    required this.problems,
  });

  final List<Map<String, String>> agents;
  final List<Map<String, String>> members;
  final List<Map<String, String>> payments;
  final List<Problem> problems;

  double get paymentTotal =>
      payments.fold(0, (sum, p) => sum + double.parse(p['amount']!));

  String exceptionsCsv() => toCsv([
        ['file', 'line', 'column', 'value', 'problem'],
        for (final p in problems) p.toRow(),
      ]);

  String summary({
    required int agentRows,
    required int memberRows,
    required int paymentRows,
  }) {
    String line(String label, int ok, int total) =>
        '$label: $ok of $total rows valid${ok == total ? '' : ' (${total - ok} rejected)'}';
    return [
      line('Agents', agents.length, agentRows),
      line('Members', members.length, memberRows),
      line('Payments', payments.length, paymentRows),
      'Payment total (valid rows): ${paymentTotal.toStringAsFixed(2)}',
      'Problems listed: ${problems.length}',
    ].join('\n');
  }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

typedef _Rule = String? Function(String value, Map<String, String> row);

class _Column {
  const _Column(this.name, {this.required = false, this.normalize, this.rule});

  final String name;
  final bool required;

  /// Returns the cleaned value, or null when it cannot be understood.
  final String? Function(String value)? normalize;
  final _Rule? rule;
}

String? _digits(String v, int length) {
  var d = v.replaceAll(RegExp(r'[\s\-()]'), '');
  if (length == 10) {
    if (d.startsWith('+91')) d = d.substring(3);
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  }
  // Excel may turn long numbers into 9.87654E+09; that value is lost.
  return RegExp('^\\d{$length}\$').hasMatch(d) ? d : null;
}

/// Accepts 31-12-2025, 31/12/2025, 31.12.2025 and 2025-12-31.
String? normalizeDate(String v) {
  final s = v.trim();
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  int y, mo, d;
  if (m != null) {
    y = int.parse(m[1]!);
    mo = int.parse(m[2]!);
    d = int.parse(m[3]!);
  } else {
    m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(s);
    if (m == null) return null;
    d = int.parse(m[1]!);
    mo = int.parse(m[2]!);
    y = int.parse(m[3]!);
  }
  final date = DateTime(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) return null;
  if (y < 1950 || date.isAfter(DateTime.now().add(const Duration(days: 1)))) {
    return null;
  }
  return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}';
}

String? Function(String) _oneOf(Map<String, String> aliases) => (v) {
      final key = v.trim().toLowerCase();
      return aliases[key];
    };

final _gender = _oneOf({
  'male': 'male', 'm': 'male', 'पुरुष': 'male',
  'female': 'female', 'f': 'female', 'महिला': 'female', 'स्त्री': 'female',
  'other': 'other', 'अन्य': 'other',
});

final _memberStatus = _oneOf({
  'active': 'active', 'सक्रिय': 'active',
  'inactive': 'inactive', 'निष्क्रिय': 'inactive',
  'closed': 'closed', 'बंद': 'closed',
});

final _paymentMode = _oneOf({
  'cash': 'cash', 'नकद': 'cash',
  'upi': 'upi',
  'bank': 'bank', 'bank transfer': 'bank', 'neft': 'bank', 'rtgs': 'bank', 'imps': 'bank',
  'cheque': 'cheque', 'check': 'cheque', 'चेक': 'cheque',
});

final _paymentStatus = _oneOf({
  'paid': 'paid', 'pending': 'pending', 'failed': 'failed',
});

final _paymentKind = _oneOf({
  'registration': 'registration', 'पंजीकरण': 'registration',
  'contribution': 'contribution', 'सहयोग': 'contribution',
  'closing payout': 'closingPayout', 'closingpayout': 'closingPayout', 'payout': 'closingPayout',
});

String? _amount(String v) {
  final cleaned = v.replaceAll(RegExp(r'[₹,\s]'), '');
  final n = double.tryParse(cleaned);
  if (n == null || n <= 0 || n >= 10000000000) return null;
  return n.toStringAsFixed(2);
}

String? _percent(String v) {
  final n = double.tryParse(v.replaceAll('%', '').trim());
  return n == null || n < 0 || n > 100 ? null : n.toString();
}

String? _upper(String v) => v.trim().toUpperCase();

const _agentColumns = <_Column>[
  _Column('code', normalize: _upper, rule: _agentCode),
  _Column('name', required: true),
  _Column('phone', normalize: _phone),
  _Column('email'),
  _Column('area'),
  _Column('district'),
  _Column('commission_percent', normalize: _percent),
  _Column('join_date', normalize: normalizeDate),
];

final _memberColumns = <_Column>[
  const _Column('reg_no', normalize: _upper, rule: _regNo),
  const _Column('yojna_code', required: true, normalize: _upper, rule: _yojnaCode),
  const _Column('name', required: true),
  const _Column('father_or_husband_name'),
  const _Column('jati'),
  const _Column('gotra'),
  const _Column('waris_name'),
  const _Column('waris_relation'),
  _Column('gender', normalize: _gender),
  const _Column('primary_phone', required: true, normalize: _phone),
  const _Column('alt_phone', normalize: _phone),
  const _Column('aadhaar', normalize: _aadhaar),
  const _Column('village'),
  const _Column('tehsil'),
  const _Column('district'),
  const _Column('pincode', normalize: _pincode),
  const _Column('agent_code', normalize: _upper, rule: _agentCode),
  const _Column('join_date', normalize: normalizeDate),
  _Column('status', normalize: _memberStatus),
];

final _paymentColumns = <_Column>[
  const _Column('receipt_no', normalize: _upper, rule: _receiptNo),
  const _Column('reg_no', required: true, normalize: _upper, rule: _regNo),
  const _Column('amount', required: true, normalize: _amount),
  const _Column('date', required: true, normalize: normalizeDate),
  _Column('mode', normalize: _paymentMode),
  _Column('status', normalize: _paymentStatus),
  _Column('kind', normalize: _paymentKind),
  const _Column('agent_code', normalize: _upper, rule: _agentCode),
  const _Column('reference'),
  const _Column('note'),
];

String? _phone(String v) => _digits(v, 10);
String? _aadhaar(String v) => _digits(v, 12);
String? _pincode(String v) => _digits(v, 6);

String? _agentCode(String v, Map<String, String> _) =>
    RegExp(r'^AG-\d{3,}$').hasMatch(v) ? null : 'must look like AG-007';
String? _regNo(String v, Map<String, String> _) =>
    RegExp(r'^[A-Z]{2,6}-\d{4}-\d{4,}$').hasMatch(v)
        ? null
        : 'must look like SSY-2026-0184';
String? _receiptNo(String v, Map<String, String> _) =>
    RegExp(r'^RCP-\d+$').hasMatch(v) ? null : 'must look like RCP-1001';
String? _yojnaCode(String v, Map<String, String> _) =>
    RegExp(r'^[A-Z]{2,6}$').hasMatch(v) ? null : '2–6 English capital letters';

String _describe(_Column c) => switch (c.name) {
      'phone' || 'primary_phone' || 'alt_phone' => 'must be a 10-digit mobile number',
      'aadhaar' => 'must be 12 digits',
      'pincode' => 'must be 6 digits',
      'join_date' || 'date' => 'use DD-MM-YYYY (not in the future)',
      'amount' => 'must be a number greater than 0',
      'commission_percent' => 'must be between 0 and 100',
      'gender' => 'use male / female / other (or पुरुष / महिला / अन्य)',
      'status' => 'unknown status',
      'mode' => 'use cash / upi / bank / cheque',
      'kind' => 'use registration / contribution / closing payout',
      _ => 'invalid value',
    };

/// Validates rows against [columns]. Returns normalized valid rows; problems
/// for rejected rows go to [problems].
List<(int, Map<String, String>)> _validate(
  String file,
  List<List<String>> csv,
  List<_Column> columns,
  List<Problem> problems,
) {
  if (csv.isEmpty) return const [];
  final header = csv.first.map((h) => h.trim().toLowerCase()).toList();

  final known = {for (final c in columns) c.name};
  for (final c in columns.where((c) => c.required)) {
    if (!header.contains(c.name)) {
      problems.add(Problem(file, 1, c.name, '', 'required column is missing'));
    }
  }
  for (final h in header) {
    if (h.isNotEmpty && !known.contains(h)) {
      problems.add(Problem(file, 1, h, '', 'unknown column (ignored)'));
    }
  }
  if (columns.any((c) => c.required && !header.contains(c.name))) {
    return const [];
  }

  final valid = <(int, Map<String, String>)>[];
  for (var i = 1; i < csv.length; i++) {
    final line = i + 1;
    final raw = <String, String>{
      for (var j = 0; j < header.length; j++)
        header[j]: j < csv[i].length
            ? csv[i][j].replaceAll(RegExp(r'\s+'), ' ').trim()
            : '',
    };
    final row = <String, String>{};
    var ok = true;

    for (final c in columns) {
      final value = raw[c.name] ?? '';
      if (value.isEmpty) {
        if (c.required) {
          problems.add(Problem(file, line, c.name, '', 'required'));
          ok = false;
        }
        row[c.name] = '';
        continue;
      }
      final normalized = c.normalize == null ? value : c.normalize!(value);
      if (normalized == null) {
        problems.add(Problem(file, line, c.name, value, _describe(c)));
        ok = false;
        continue;
      }
      final error = c.rule?.call(normalized, raw);
      if (error != null) {
        problems.add(Problem(file, line, c.name, value, error));
        ok = false;
        continue;
      }
      row[c.name] = normalized;
    }
    if (ok) valid.add((line, row));
  }
  return valid;
}

/// Drops rows whose [key] repeats an earlier row, reporting each repeat.
List<(int, Map<String, String>)> _unique(
  String file,
  String key,
  List<(int, Map<String, String>)> rows,
  List<Problem> problems,
) {
  final firstLine = <String, int>{};
  final result = <(int, Map<String, String>)>[];
  for (final (line, row) in rows) {
    final value = row[key]!;
    if (value.isNotEmpty) {
      final seen = firstLine[value];
      if (seen != null) {
        problems.add(
          Problem(file, line, key, value, 'duplicate of line $seen'),
        );
        continue;
      }
      firstLine[value] = line;
    }
    result.add((line, row));
  }
  return result;
}

ImportResult validateImport({
  List<List<String>>? agentsCsv,
  List<List<String>>? membersCsv,
  List<List<String>>? paymentsCsv,
}) {
  final problems = <Problem>[];

  final agents = _unique(
    'agents',
    'code',
    _validate('agents', agentsCsv ?? const [], _agentColumns, problems),
    problems,
  );

  var members = _validate(
    'members',
    membersCsv ?? const [],
    _memberColumns,
    problems,
  );
  members = _unique('members', 'reg_no', members, problems);

  // Payments that point at a member row rejected above cannot be imported.
  final rejectedRegNos = <String>{};
  if (membersCsv != null && membersCsv.length > 1) {
    final header = membersCsv.first.map((h) => h.trim().toLowerCase()).toList();
    final regCol = header.indexOf('reg_no');
    final validRegNos = {for (final (_, m) in members) m['reg_no']};
    if (regCol >= 0) {
      for (final r in membersCsv.skip(1)) {
        if (regCol < r.length) {
          final reg = r[regCol].trim().toUpperCase();
          if (reg.isNotEmpty && !validRegNos.contains(reg)) rejectedRegNos.add(reg);
        }
      }
    }
  }

  var payments = _validate(
    'payments',
    paymentsCsv ?? const [],
    _paymentColumns,
    problems,
  );
  payments = _unique('payments', 'receipt_no', payments, problems);
  final linkedPayments = <(int, Map<String, String>)>[];
  for (final (line, p) in payments) {
    if (rejectedRegNos.contains(p['reg_no'])) {
      problems.add(Problem('payments', line, 'reg_no', p['reg_no']!,
          'member row was rejected; fix it in members.csv first'));
    } else {
      linkedPayments.add((line, p));
    }
  }
  payments = linkedPayments;

  problems.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });

  return ImportResult(
    agents: agents.map((e) => e.$2).toList(),
    members: members.map((e) => e.$2).toList(),
    payments: payments.map((e) => e.$2).toList(),
    problems: problems,
  );
}

// ---------------------------------------------------------------------------
// SQL
// ---------------------------------------------------------------------------

String _lit(String v) => "'${v.replaceAll("'", "''")}'";

/// Empty string stays empty; use `nullif(x, '')` in SQL where null is needed.
String _values(List<Map<String, String>> rows, List<String> columns) => rows
    .map((r) => '  (${columns.map((c) => _lit(r[c] ?? '')).join(', ')})')
    .join(',\n');

Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, (i + size).clamp(0, list.length));
  }
}

String _check(String title, String query) => '''
do \$\$
declare missing text;
begin
  $query
  if missing is not null then
    raise exception '$title: %', missing;
  end if;
end \$\$;
''';


/// Moves every counter past the highest number already in the tables, so
/// generated numbers never collide with imported ones.
const _syncCounters = r'''
insert into public.counters (key, value)
select split_part(reg_no, '-', 1) || '-' || split_part(reg_no, '-', 2),
       max(split_part(reg_no, '-', 3)::int)
  from public.members where reg_no ~ '^[A-Z]{2,6}-\d{4}-\d+$'
 group by 1
union all
select 'RCP', max(split_part(receipt_no, '-', 2)::int) - 1000
  from public.payments where receipt_no ~ '^RCP-\d+$'
having max(split_part(receipt_no, '-', 2)::int) > 1000
union all
select 'AG', max(split_part(code, '-', 2)::int)
  from public.agents where code ~ '^AG-\d+$'
having count(*) > 0
on conflict (key) do update set value = greatest(public.counters.value, excluded.value);
''';

const _agentCols = [
  'code', 'name', 'phone', 'email', 'area', 'district', 'commission_percent',
  'join_date',
];

const _memberCols = [
  'reg_no', 'yojna_code', 'name', 'father_or_husband_name', 'jati', 'gotra',
  'waris_name', 'waris_relation', 'gender', 'primary_phone', 'alt_phone',
  'aadhaar', 'village', 'tehsil', 'district', 'pincode', 'agent_code',
  'join_date', 'status',
];

const _paymentCols = [
  'receipt_no', 'reg_no', 'amount', 'date', 'mode', 'status', 'kind',
  'agent_code', 'reference', 'note',
];

void _insertAgents(StringBuffer out, List<Map<String, String>> rows) {
  for (final chunk in _chunks(rows, 500)) {
    out.writeln('''
insert into public.agents (code, name, phone, email, area, district, commission_percent, join_date)
select v.code, v.name, v.phone, v.email, v.area, v.district,
       coalesce(nullif(v.commission_percent, '')::numeric, 0),
       coalesce(nullif(v.join_date, '')::date, current_date)
from (values
${_values(chunk, _agentCols)}
) as v(${_agentCols.join(', ')})
order by v.join_date, v.name;
''');
  }
}

void _insertMembers(StringBuffer out, List<Map<String, String>> rows) {
  for (final chunk in _chunks(rows, 500)) {
    out.writeln('''
insert into public.members (reg_no, yojna_id, name, father_or_husband_name, jati, gotra,
  waris_name, waris_relation, gender, primary_phone, alt_phone, aadhaar, village, tehsil,
  district, pincode, agent_id, join_date, status)
select v.reg_no, y.id, v.name, v.father_or_husband_name, v.jati, v.gotra,
       v.waris_name, v.waris_relation,
       coalesce(nullif(v.gender, ''), 'male')::public.gender,
       v.primary_phone, v.alt_phone, v.aadhaar, v.village, v.tehsil, v.district, v.pincode,
       a.id,
       coalesce(nullif(v.join_date, '')::date, current_date),
       coalesce(nullif(v.status, ''), 'active')::public.member_status
from (values
${_values(chunk, _memberCols)}
) as v(${_memberCols.join(', ')})
join public.yojnas y on y.code = v.yojna_code
left join public.agents a on a.code = nullif(v.agent_code, '')
order by v.reg_no, v.join_date;
''');
  }
}

void _insertPayments(StringBuffer out, List<Map<String, String>> rows) {
  for (final chunk in _chunks(rows, 500)) {
    out.writeln('''
insert into public.payments (receipt_no, member_id, yojna_id, amount, date, mode, status, kind,
  agent_id, reference, note)
select v.receipt_no, m.id, m.yojna_id, v.amount::numeric, v.date::date,
       coalesce(nullif(v.mode, ''), 'cash')::public.payment_mode,
       coalesce(nullif(v.status, ''), 'paid')::public.payment_status,
       coalesce(nullif(v.kind, ''), 'contribution')::public.payment_kind,
       coalesce(a.id, m.agent_id), v.reference, v.note
from (values
${_values(chunk, _paymentCols)}
) as v(${_paymentCols.join(', ')})
join public.members m on m.reg_no = v.reg_no
left join public.agents a on a.code = nullif(v.agent_code, '')
order by v.date, v.receipt_no;
''');
  }
}

String _mustExist(String title, Iterable<String> values, String table, String column) {
  final list = values.where((v) => v.isNotEmpty).toSet().toList()..sort();
  if (list.isEmpty) return '';
  return _check(
    title,
    "select string_agg(c, ', ') into missing from unnest(array[${list.map(_lit).join(', ')}]) c\n"
        '   where not exists (select 1 from public.$table t where t.$column = c);',
  );
}

String _mustNotExist(String title, Iterable<String> values, String table, String column) {
  final list = values.where((v) => v.isNotEmpty).toSet().toList()..sort();
  if (list.isEmpty) return '';
  return _check(
    title,
    "select string_agg(c, ', ') into missing from unnest(array[${list.map(_lit).join(', ')}]) c\n"
        '   where exists (select 1 from public.$table t where t.$column = c);',
  );
}

/// One transaction: any failure rolls back everything.
///
/// Rows that carry their own number go in first; then the counters move past
/// them, and rows with a blank number get fresh ones from the database.
String buildSql(ImportResult r) {
  bool has(Map<String, String> row, String key) => row[key]!.isNotEmpty;

  final out = StringBuffer()
    ..writeln('-- Generated by tool/import_data.dart. Review the exceptions')
    ..writeln('-- report first. Run with: psql "<db url>" -v ON_ERROR_STOP=1 -f import.sql')
    ..writeln()
    ..writeln('begin;')
    ..writeln()
    ..writeln('-- Every Yojna must already exist (create them in the app).')
    ..writeln(_mustExist(
      'Create these Yojnas in the app before importing',
      r.members.map((m) => m['yojna_code']!),
      'yojnas',
      'code',
    ))
    ..writeln('-- Numbers in the files must not be in use already.')
    ..writeln(_mustNotExist('These agent codes already exist',
        r.agents.map((a) => a['code']!), 'agents', 'code'))
    ..writeln(_mustNotExist('These registration numbers already exist',
        r.members.map((m) => m['reg_no']!), 'members', 'reg_no'))
    ..writeln(_mustNotExist('These receipt numbers already exist',
        r.payments.map((p) => p['receipt_no']!), 'payments', 'receipt_no'))
    ..writeln('-- Agents')
    ..writeln(_syncCounters);
  _insertAgents(out, r.agents.where((a) => has(a, 'code')).toList());
  out.writeln(_syncCounters);
  _insertAgents(out, r.agents.where((a) => !has(a, 'code')).toList());

  out
    ..writeln(_mustExist(
      'These agent codes do not exist',
      [
        ...r.members.map((m) => m['agent_code']!),
        ...r.payments.map((p) => p['agent_code']!),
      ],
      'agents',
      'code',
    ))
    ..writeln('-- Members');
  _insertMembers(out, r.members.where((m) => has(m, 'reg_no')).toList());
  out.writeln(_syncCounters);
  _insertMembers(out, r.members.where((m) => !has(m, 'reg_no')).toList());

  out
    ..writeln(_mustExist(
      'Payments refer to these unknown registration numbers',
      r.payments.map((p) => p['reg_no']!),
      'members',
      'reg_no',
    ))
    ..writeln('-- Payments');
  _insertPayments(out, r.payments.where((p) => has(p, 'receipt_no')).toList());
  out.writeln(_syncCounters);
  _insertPayments(out, r.payments.where((p) => !has(p, 'receipt_no')).toList());

  out
    ..writeln('-- Compare with the import summary before committing.')
    ..writeln("select 'agents' as table_name, count(*) as rows from public.agents")
    ..writeln("union all select 'members', count(*) from public.members")
    ..writeln("union all select 'payments', count(*) from public.payments;")
    ..writeln('select coalesce(sum(amount), 0) as payment_total from public.payments;')
    ..writeln()
    ..writeln('commit;');

  return out.toString();
}
