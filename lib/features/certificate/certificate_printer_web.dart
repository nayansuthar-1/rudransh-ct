import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'certificate_data.dart';
import 'certificate_html.dart';

/// How long the object URL is kept alive. The new tab only needs it while it
/// loads; a minute is generous and keeps the blob from leaking for the rest of
/// the session.
const _urlLifetime = Duration(minutes: 1);

/// Opens the certificate in a new tab, which prints itself once it has loaded.
/// [pair] goes on the same A4 sheet, in its bottom half.
///
/// The page is handed over as a `blob:` URL rather than written into the new
/// window, so it is a real document with its own charset and can load the
/// bundled Devanagari font from this origin. Blob URLs cannot resolve relative
/// paths, which is why the template is given an absolute base URL.
///
/// Returns false when the browser blocked the pop-up — the caller then tells
/// the person to allow pop-ups for the site.
Future<bool> openCertificateForPrint(
  CertificateData data, {
  CertificateData? pair,
}) async {
  final html = buildCertificateHtml(
    data,
    baseUrl: web.document.baseURI,
    pair: pair,
  );
  final blob = web.Blob(
    <JSAny>[html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);

  final opened = web.window.open(url, '_blank');
  if (opened == null) {
    web.URL.revokeObjectURL(url);
    return false;
  }

  Future<void>.delayed(_urlLifetime, () => web.URL.revokeObjectURL(url));
  return true;
}
