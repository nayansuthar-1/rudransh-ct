/// Comma-separated values for spreadsheet export.
///
/// Starts with a byte-order mark so Excel reads the file as UTF-8 — without it
/// Hindi names open as mojibake. Rows end in CRLF, as RFC 4180 and Excel
/// expect.
String toCsv(List<List<Object?>> rows) {
  final out = StringBuffer('﻿');
  for (final row in rows) {
    out
      ..write(row.map(_cell).join(','))
      ..write('\r\n');
  }
  return out.toString();
}

String _cell(Object? value) {
  final text = value?.toString() ?? '';
  // A leading =, +, - or @ makes a spreadsheet run the cell as a formula;
  // a stray apostrophe keeps it plain text (CSV injection).
  final safe = text.startsWith(RegExp(r'[=+\-@]')) ? "'$text" : text;
  if (safe.contains(RegExp(r'[",\r\n]'))) {
    return '"${safe.replaceAll('"', '""')}"';
  }
  return safe;
}
