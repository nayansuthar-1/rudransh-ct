import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'receipt_data.dart';
import 'receipt_html.dart';

const _urlLifetime = Duration(minutes: 1);

/// Opens the payment receipt in a new tab for printing.
Future<bool> openReceiptForPrint(ReceiptData data) async {
  final html = buildReceiptHtml(data, baseUrl: web.document.baseURI);
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
