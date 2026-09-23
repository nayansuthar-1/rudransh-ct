import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../widgets/app_dialog.dart';
import 'receipt_data.dart';
import 'receipt_printer.dart';

/// Opens the payment receipt in a new tab for printing.
Future<void> printPaymentReceipt(
  BuildContext context, {
  required Payment payment,
  Member? member,
  MemberRef? memberRef,
  Yojna? yojna,
  Agent? agent,
  String agentName = '',
  String yojnaName = '',
}) async {
  if (payment.receiptNo.trim().isEmpty) {
    showToast(context, 'This payment has no receipt number yet.', error: true);
    return;
  }

  final opened = await openReceiptForPrint(
    ReceiptData.fromPayment(
      payment: payment,
      member: member,
      memberRef: memberRef,
      yojna: yojna,
      agent: agent,
      agentName: agentName,
      yojnaName: yojnaName,
    ),
  );

  if (!opened && context.mounted) {
    showToast(
      context,
      'Could not open receipt for print. Allow pop-ups for this site.',
      error: true,
    );
  }
}
