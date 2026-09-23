import 'receipt_data.dart';

/// Non-web builds fallback.
Future<bool> openReceiptForPrint(ReceiptData data) async => false;
