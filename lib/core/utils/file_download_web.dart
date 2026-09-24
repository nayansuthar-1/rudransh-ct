import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Saves [content] as a file through the browser's download, via a `blob:`
/// URL and a clicked link. Returns false when the browser offers no document.
Future<bool> downloadTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv',
}) async {
  final blob = web.Blob(
    <JSAny>[content.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(link);
  link.click();
  link.remove();
  // The click has started the download; the URL is not needed after it.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
