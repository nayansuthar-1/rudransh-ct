import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
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

/// A certificate kept back to share the next one's A4 sheet. It lives only as
/// long as the tab: a reload drops it, which costs nothing but a reprint.
CertificateData? _waiting;

/// Prints a member's certificate, two to an A4 sheet: the first can be kept
/// back and goes out with the next one printed.
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

  final data = CertificateData.forMember(
    member: member,
    yojna: yojna,
    agent: agent,
    agentName: agentName,
  );
  // The same member twice is a reprint, not a pair.
  final waiting = _waiting?.regNo == data.regNo ? null : _waiting;

  final choice = await _askPairing(context, data, waiting);
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _Pairing.keep:
      _waiting = data;
      showToast(context, S.certificateKept);
      return;
    case _Pairing.alone:
      // Another member kept back still waits; this member's own kept copy
      // is the one being printed.
      if (waiting == null) _waiting = null;
    case _Pairing.both:
      _waiting = null;
  }

  final opened = await openCertificateForPrint(
    data,
    pair: choice == _Pairing.both ? waiting : null,
  );
  if (!opened && context.mounted) {
    // Nothing printed, so the kept certificate still waits for its pair.
    if (choice == _Pairing.both) _waiting = waiting;
    showToast(context, S.certificateFailed, error: true);
  }
}

enum _Pairing { keep, alone, both }

/// Asks whether to print [data] now, keep it for the next one, or print it
/// with the certificate already [waiting].
Future<_Pairing?> _askPairing(
  BuildContext context,
  CertificateData data,
  CertificateData? waiting,
) {
  final c = context.colors;
  final message = waiting == null
      ? 'Print ${data.name} now, or keep it and print it with the next '
          'certificate you open.'
      : '${waiting.name} (${waiting.regNo}) is waiting. Print both on one '
          'sheet?';

  return showDialog<_Pairing>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (dialogContext) {
      void pick(_Pairing p) => Navigator.of(dialogContext).pop(p);
      return AlertDialog(
        constraints: const BoxConstraints(maxWidth: 440),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: const Text(S.printCertificate),
        content: Text(
          '${S.certificateSheetNote} $message',
          style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(S.cancel),
          ),
          if (waiting == null) ...[
            OutlinedButton(
              onPressed: () => pick(_Pairing.keep),
              child: const Text(S.certificateKeep),
            ),
            FilledButton(
              onPressed: () => pick(_Pairing.alone),
              child: const Text(S.certificatePrintNow),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => pick(_Pairing.alone),
              child: const Text(S.certificatePrintOne),
            ),
            FilledButton(
              onPressed: () => pick(_Pairing.both),
              child: const Text(S.certificatePrintBoth),
            ),
          ],
        ],
      );
    },
  );
}
