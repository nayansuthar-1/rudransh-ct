import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/csv.dart';
import '../../core/utils/file_download.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../widgets/app_dialog.dart';

/// Rows fetched per request while exporting. The trust has about 2,000
/// members, so an export is a handful of requests.
const _chunk = 500;

final _day = DateFormat('dd-MM-yyyy');
final _stamp = DateFormat('yyyy-MM-dd');

String _date(DateTime? d) => d == null ? '' : _day.format(d);

/// Aadhaar never leaves the app in full: the last four, masked.
String _maskedAadhaar(Member m) =>
    m.aadhaarLast4.isEmpty ? '' : 'XXXX XXXX ${m.aadhaarLast4}';

/// The members sheet: a header row, then one row per member.
List<List<Object?>> memberCsvRows(
  List<Member> members, {
  required Map<String, Yojna> yojnas,
  required Map<String, Agent> agents,
}) =>
    [
      const [
        'Reg no', 'Name', 'Father/Husband', 'Jati', 'Gotra', 'Date of birth',
        'Gender', 'Phone', 'Alt phone', 'Email', 'Aadhaar', 'Village', 'Tehsil',
        'District', 'State', 'Pincode', 'Waris', 'Relation', 'Yojna', 'Agent',
        'Joined', 'Status', 'Closing date',
      ],
      for (final m in members)
        [
          m.regNo, m.name, m.fatherOrHusbandName, m.jati, m.gotra, _date(m.dob),
          m.gender.label, m.primaryPhone, m.altPhone, m.email, _maskedAadhaar(m),
          m.village, m.tehsil, m.district, m.state, m.pincode, m.warisName,
          m.warisRelation, yojnas[m.yojnaId]?.name ?? '',
          agents[m.agentId]?.name ?? '', _date(m.joinDate), m.status.label,
          _date(m.closingDate),
        ],
    ];

/// The payments sheet: a header row, then one row per payment. Cancelled
/// receipts stay in, marked, as they do on the Payments page.
List<List<Object?>> paymentCsvRows(
  List<Payment> payments, {
  required Map<String, MemberRef> members,
  required Map<String, Yojna> yojnas,
  required Map<String, Agent> agents,
}) =>
    [
      const [
        'Receipt no', 'Date', 'Reg no', 'Member', 'Yojna', 'Amount', 'Mode',
        'Type', 'Status', 'Source', 'Reference', 'Closing group', 'Agent',
        'Note',
      ],
      for (final p in payments)
        [
          p.receiptNo, _date(p.date), members[p.memberId]?.regNo ?? '',
          members[p.memberId]?.name ?? '', yojnas[p.yojnaId]?.name ?? '',
          p.amount.toStringAsFixed(2), p.mode.label, p.kind.label,
          p.isCancelled ? 'Cancelled' : p.status.label, p.source.label,
          p.reference, p.closingGroup, agents[p.agentId]?.name ?? '', p.note,
        ],
    ];

/// The dues sheet: a header row, then one row per member.
List<List<Object?>> duesCsvRows(
  List<MemberDuesSummary> rows, {
  required Map<String, Yojna> yojnas,
  required Map<String, Agent> agents,
}) =>
    [
      const [
        'Reg no', 'Name', 'Phone', 'Village', 'Yojna', 'Agent', 'Status',
        'Closings owed', 'Total due', 'Waiting for approval', 'Contributed',
        'Last contribution',
      ],
      for (final s in rows)
        [
          s.regNo, s.name, s.phone, s.village, yojnas[s.yojnaId]?.name ?? '',
          agents[s.agentId]?.name ?? '', s.status.label, s.closingsOwed,
          s.due.toStringAsFixed(2), s.pending.toStringAsFixed(2),
          s.contributed.toStringAsFixed(2), _date(s.lastContribution),
        ],
    ];

/// Every member matching the Dues page's current filters, as a CSV file.
Future<void> exportDuesCsv(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final query = ref.read(duesQueryProvider);
  await _export(
    context,
    fileName: 'dues-${_stamp.format(DateTime.now())}.csv',
    build: () async {
      final all = <MemberDuesSummary>[];
      while (true) {
        final page =
            await repo.fetchDuesPage(query, offset: all.length, limit: _chunk);
        all.addAll(page.items);
        if (page.items.isEmpty || all.length >= page.total) break;
      }
      return duesCsvRows(
        all,
        yojnas: ref.read(yojnaByIdProvider),
        agents: ref.read(agentByIdProvider),
      );
    },
  );
}

/// Every member matching the Members page's current filters, as a CSV file.
Future<void> exportMembersCsv(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final query = ref.read(memberQueryProvider);
  await _export(
    context,
    fileName: 'members-${_stamp.format(DateTime.now())}.csv',
    build: () async {
      final all = <Member>[];
      while (true) {
        final page =
            await repo.fetchMembersPage(query, offset: all.length, limit: _chunk);
        all.addAll(page.items);
        if (page.items.isEmpty || all.length >= page.total) break;
      }
      return memberCsvRows(
        all,
        yojnas: ref.read(yojnaByIdProvider),
        agents: ref.read(agentByIdProvider),
      );
    },
  );
}

/// Every payment matching the Payments page's current filters, as a CSV file.
Future<void> exportPaymentsCsv(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final query = ref.read(paymentQueryProvider);
  await _export(
    context,
    fileName: 'payments-${_stamp.format(DateTime.now())}.csv',
    build: () async {
      final all = <Payment>[];
      final members = <String, MemberRef>{};
      while (true) {
        final page = await repo.fetchPaymentsPage(
          query,
          offset: all.length,
          limit: _chunk,
        );
        all.addAll(page.items);
        members.addAll(page.members);
        if (page.items.isEmpty || all.length >= page.total) break;
      }
      return paymentCsvRows(
        all,
        members: members,
        yojnas: ref.read(yojnaByIdProvider),
        agents: ref.read(agentByIdProvider),
      );
    },
  );
}

Future<void> _export(
  BuildContext context, {
  required String fileName,
  required Future<List<List<Object?>>> Function() build,
}) async {
  try {
    final rows = await build();
    final saved = await downloadTextFile(fileName, toCsv(rows));
    if (!context.mounted) return;
    if (saved) {
      final count = rows.length - 1;
      showToast(context, 'Exported $count ${count == 1 ? 'row' : 'rows'}');
    } else {
      showToast(context, 'Export works in the web app only.', error: true);
    }
  } catch (e) {
    if (context.mounted) showToast(context, '$e', error: true);
  }
}
