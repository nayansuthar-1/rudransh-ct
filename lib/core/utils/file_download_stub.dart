/// Tests and non-web builds have no browser to download into.
Future<bool> downloadTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv',
}) async =>
    false;
