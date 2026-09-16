// Validates the trust's existing records and writes an import script.
//
//   dart run tool/import_data.dart --members members.csv [--agents agents.csv]
//       [--payments payments.csv] [--out build/import]
//
// Writes <out>/exceptions.csv (share with the client), <out>/summary.txt and
// <out>/import.sql. Nothing touches a database; review, then run the SQL with
// psql against staging first. Column reference: tool/import/README.md.
import 'dart:io';

import 'import/csv_import.dart';

void main(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--') || i + 1 >= args.length) {
      _usage('Unexpected argument: $arg');
    }
    options[arg.substring(2)] = args[++i];
  }
  const allowed = {'agents', 'members', 'payments', 'out'};
  for (final key in options.keys) {
    if (!allowed.contains(key)) _usage('Unknown option --$key');
  }
  if (!options.keys.any({'agents', 'members', 'payments'}.contains)) {
    _usage('Give at least one of --agents, --members, --payments');
  }

  List<List<String>>? read(String key) {
    final path = options[key];
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) _usage('File not found: $path');
    return parseCsv(file.readAsStringSync());
  }

  final agents = read('agents');
  final members = read('members');
  final payments = read('payments');

  final result = validateImport(
    agentsCsv: agents,
    membersCsv: members,
    paymentsCsv: payments,
  );

  int rows(List<List<String>>? csv) => csv == null ? 0 : (csv.length - 1).clamp(0, 1 << 30);
  final summary = result.summary(
    agentRows: rows(agents),
    memberRows: rows(members),
    paymentRows: rows(payments),
  );

  final out = Directory(options['out'] ?? 'build/import')..createSync(recursive: true);
  // BOM so Excel opens the Hindi text correctly.
  File('${out.path}/exceptions.csv').writeAsStringSync('\uFEFF${result.exceptionsCsv()}');
  File('${out.path}/summary.txt').writeAsStringSync('$summary\n');
  File('${out.path}/import.sql').writeAsStringSync(buildSql(result));

  stdout
    ..writeln(summary)
    ..writeln()
    ..writeln('Wrote ${out.path}/exceptions.csv, summary.txt and import.sql');
  if (result.problems.isNotEmpty) exitCode = 2;
}

Never _usage(String message) {
  stderr
    ..writeln(message)
    ..writeln()
    ..writeln('Usage: dart run tool/import_data.dart --members members.csv '
        '[--agents agents.csv] [--payments payments.csv] [--out build/import]');
  exit(64);
}
