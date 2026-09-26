import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../data/models/models.dart';
import '../../widgets/app_dialog.dart';
import 'certificate_data.dart';
import 'certificate_printer.dart';

/// Opens the member's certificate in a new tab for printing, and says why when
/// it cannot (docs/MEMBERSHIP_CERTIFICATE_PLAN.md §3).
///
/// Callers pass whatever context they already hold: the admin screens have the
/// Yojna and the agent record to hand, the agent screens have their own name.
/// Anything not passed prints as a blank dotted line.
/// Prints [data] as it stands: for the member's own screens, which have the
/// certificate's fields but not the full Yojna and agent records.
Future<void> printCertificateData(
  BuildContext context,
  CertificateData data, {
  String failedMessage = S.certificateFailed,
}) async {
  final opened = await openCertificateForPrint(data);
  if (!opened && context.mounted) {
    showToast(context, failedMessage, error: true);
  }
}

Future<void> printMemberCertificate(
  BuildContext context, {
  required Member member,
  Yojna? yojna,
  Agent? agent,
  String agentName = '',
}) async {
  // An agent's sign-up has no registration number until the office approves it,
  // and a certificate without one is not worth printing.
  if (member.regNo.trim().isEmpty) {
    showToast(context, S.certificateNeedsRegNo, error: true);
    return;
  }

  final opened = await openCertificateForPrint(
    CertificateData.forMember(
      member: member,
      yojna: yojna,
      agent: agent,
      agentName: agentName,
    ),
  );
  if (!opened && context.mounted) {
    showToast(context, S.certificateFailed, error: true);
  }
}
