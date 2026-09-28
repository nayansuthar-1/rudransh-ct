import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/app_dialog.dart';

/// Shows member data in a clean, human-readable table and card format for
/// non-technical users, with options to download CSV or copy readable text.
Future<void> showMemberExportDialog(
  BuildContext context, {
  required Member member,
  required Map<String, dynamic> data,
}) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) => MemberExportDialog(member: member, data: data),
  );
}

class MemberExportDialog extends StatefulWidget {
  const MemberExportDialog({
    super.key,
    required this.member,
    required this.data,
  });

  final Member member;
  final Map<String, dynamic> data;

  @override
  State<MemberExportDialog> createState() => _MemberExportDialogState();
}

class _MemberExportDialogState extends State<MemberExportDialog> {
  bool _showRawJson = false;

  Map<String, dynamic> get _yojnaMap =>
      widget.data['yojna'] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> get _agentMap =>
      widget.data['agent'] as Map<String, dynamic>? ?? {};

  List<Map<String, dynamic>> get _payments {
    final list = widget.data['payments'] as List?;
    if (list == null) return const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  double get _totalPaid {
    return _payments.fold<double>(0, (sum, p) {
      final amt = p['amount'] ?? p['amount_rupees'] ?? 0;
      if (amt is num) return sum + amt.toDouble();
      if (amt is String) return sum + (double.tryParse(amt) ?? 0);
      return sum;
    });
  }

  String _generateCsv() {
    final m = widget.member;
    final rows = <List<Object?>>[
      ['RUDRANSH CHARITABLE TRUST - MEMBER PROFILE'],
      ['Field', 'Value'],
      ['Registration No', m.regNo],
      ['Name', m.name],
      ['Father/Husband Name', m.fatherOrHusbandName],
      ['Jati', m.jati],
      ['Gotra', m.gotra],
      ['Date of Birth', m.dob != null ? Fmt.date(m.dob) : '—'],
      ['Gender', m.gender.label],
      ['Primary Phone', m.primaryPhone],
      ['Alt Phone', m.altPhone],
      ['Email', m.email],
      ['Aadhaar', m.aadhaarLast4.isNotEmpty ? 'XXXX XXXX ${m.aadhaarLast4}' : '—'],
      ['Nominee (Waris)', m.warisName],
      ['Nominee Relation', m.warisRelation],
      ['Address', '${m.village}, ${m.tehsil}, ${m.district}, ${m.state} - ${m.pincode}'],
      ['Scheme (Yojna)', _yojnaMap['name'] ?? m.yojnaId],
      ['Agent', _agentMap['name'] ?? m.agentId ?? '—'],
      ['Joined Date', Fmt.date(m.joinDate)],
      ['Status', m.status.label],
      ['Contribution Amount', '₹${m.contributionAmount}'],
      [],
      ['PAYMENTS & RECEIPTS HISTORY'],
      ['Receipt No', 'Date', 'Type', 'Payment Mode', 'Status', 'Amount (INR)'],
    ];

    for (final p in _payments) {
      final d = p['date'] != null ? DateTime.tryParse(p['date'].toString()) : null;
      rows.add([
        p['receipt_no'] ?? p['receiptNo'] ?? '—',
        d != null ? Fmt.date(d) : '—',
        p['kind'] ?? '',
        p['mode'] ?? '',
        p['status'] ?? '',
        p['amount'] ?? 0,
      ]);
    }
    rows.add(['', '', '', '', 'Total Paid', _totalPaid]);
    return toCsv(rows);
  }

  String _generateReadableText() {
    final m = widget.member;
    final buf = StringBuffer();
    buf.writeln('========================================');
    buf.writeln('RUDRANSH CHARITABLE TRUST');
    buf.writeln('MEMBER DETAILS & ACCOUNT SUMMARY');
    buf.writeln('========================================');
    buf.writeln('Reg No          : ${m.regNo}');
    buf.writeln('Member Name     : ${m.name}');
    buf.writeln('Father/Husband  : ${m.fatherOrHusbandName}');
    buf.writeln('Jati / Gotra    : ${m.jati} / ${m.gotra.isNotEmpty ? m.gotra : '—'}');
    buf.writeln('Date of Birth   : ${m.dob != null ? Fmt.date(m.dob) : '—'} (${m.gender.label})');
    buf.writeln('Phone           : ${m.primaryPhone} ${m.altPhone.isNotEmpty ? '/ ${m.altPhone}' : ''}');
    buf.writeln('Nominee (Waris) : ${m.warisName} (${m.warisRelation})');
    buf.writeln('Aadhaar (Last4) : ${m.aadhaarLast4.isNotEmpty ? 'XXXX XXXX ${m.aadhaarLast4}' : '—'}');
    buf.writeln('Address         : ${m.village}, ${m.tehsil}, ${m.district}, ${m.state} ${m.pincode}');
    buf.writeln('Yojna (Scheme)  : ${_yojnaMap['name'] ?? m.yojnaId}');
    buf.writeln('Agent           : ${_agentMap['name'] ?? m.agentId ?? 'Direct'}');
    buf.writeln('Join Date       : ${Fmt.date(m.joinDate)}');
    buf.writeln('Status          : ${m.status.label}');
    buf.writeln('Contribution    : ₹${m.contributionAmount}');
    buf.writeln('----------------------------------------');
    buf.writeln('RECEIPTS & PAYMENTS HISTORY (${_payments.length}):');
    if (_payments.isEmpty) {
      buf.writeln('No payments recorded.');
    } else {
      for (final p in _payments) {
        final rNo = p['receipt_no'] ?? p['receiptNo'] ?? '—';
        final d = p['date'] != null ? Fmt.date(DateTime.tryParse(p['date'].toString())) : '—';
        final kind = p['kind'] ?? '';
        final mode = p['mode'] ?? '';
        final amt = p['amount'] ?? 0;
        buf.writeln('• Receipt #$rNo | $d | $kind | $mode | ₹$amt');
      }
      buf.writeln('Total Paid: ₹$_totalPaid');
    }
    buf.writeln('========================================');
    return buf.toString();
  }

  Future<void> _downloadCsv() async {
    final fileName = '${widget.member.regNo}_data.csv';
    final saved = await downloadTextFile(fileName, _generateCsv());
    if (!mounted) return;
    if (saved) {
      showToast(context, 'Downloaded $fileName');
    } else {
      showToast(context, 'Downloading works in browser/web view.', error: true);
    }
  }

  Future<void> _copyText() async {
    final text = _showRawJson
        ? const JsonEncoder.withIndent('  ').convert(widget.data)
        : _generateReadableText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showToast(context, _showRawJson ? 'JSON copied to clipboard' : 'Member details copied');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.member;

    return AppDialog(
      title: '${S.exportData}: ${m.name}',
      subtitle: '${m.regNo} · ${_yojnaMap['name'] ?? ''}',
      maxWidth: 780,
      actions: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _showRawJson = !_showRawJson),
          icon: Icon(_showRawJson ? Icons.table_chart_outlined : Icons.code, size: 16),
          label: Text(_showRawJson ? 'View as Table' : 'Raw JSON'),
        ),
        OutlinedButton.icon(
          onPressed: _downloadCsv,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download CSV'),
        ),
        FilledButton.icon(
          onPressed: _copyText,
          icon: const Icon(Icons.copy_all_outlined, size: 16),
          label: const Text('Copy Details'),
        ),
      ],
      child: _showRawJson ? _buildRawJsonView(c) : _buildHumanTableView(c, m),
    );
  }

  Widget _buildRawJsonView(AppColors c) {
    final text = const JsonEncoder.withIndent('  ').convert(widget.data);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildHumanTableView(AppColors c, Member m) {
    final payments = _payments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top summary banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.brand.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: c.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reg. No: ${m.regNo}  ·  Joined: ${Fmt.date(m.joinDate)}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: m.status == MemberStatus.active
                      ? c.success.withValues(alpha: 0.15)
                      : c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: m.status == MemberStatus.active ? c.success : c.border,
                  ),
                ),
                child: Text(
                  m.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: m.status == MemberStatus.active ? c.success : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section: Personal details
        _SectionHeader(title: 'Member Details (सदस्य विवरण)', icon: Icons.badge_outlined),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _InfoRow('Father / Husband', m.fatherOrHusbandName, 'Gender / DOB', '${m.gender.label} · ${m.dob != null ? Fmt.date(m.dob) : '—'}'),
              _divider(c),
              _InfoRow('Jati / Gotra', '${m.jati} / ${m.gotra.isNotEmpty ? m.gotra : '—'}', 'Aadhaar Card', m.aadhaarLast4.isNotEmpty ? 'XXXX XXXX ${m.aadhaarLast4}' : '—'),
              _divider(c),
              _InfoRow('Nominee (Waris)', m.warisName, 'Relation', m.warisRelation),
              _divider(c),
              _InfoRow('Primary Phone', m.primaryPhone, 'Alt Phone', m.altPhone.isNotEmpty ? m.altPhone : '—'),
              _divider(c),
              _InfoRow('Email', m.email.isNotEmpty ? m.email : '—', 'Scheme (Yojna)', _yojnaMap['name']?.toString() ?? '—'),
              _divider(c),
              _InfoRow('Address', '${m.village}, ${m.tehsil}, ${m.district}', 'State / PIN', '${m.state} - ${m.pincode}'),
              _divider(c),
              _InfoRow('Contribution Amount', '₹${m.contributionAmount}', 'Agent', _agentMap['name']?.toString() ?? 'Direct / None'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: Payments
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(
              title: 'Payments & Receipts (${payments.length}) (जमा रसीदें)',
              icon: Icons.receipt_long_outlined,
            ),
            if (payments.isNotEmpty)
              Text(
                'Total: ₹${Fmt.money(_totalPaid)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: payments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_outlined, size: 32, color: c.textSecondary),
                        const SizedBox(height: 6),
                        Text(
                          'No receipts recorded for this member',
                          style: TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 40,
                    horizontalMargin: 12,
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('Receipt #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataColumn(numeric: true, label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    ],
                    rows: [
                      for (final p in payments)
                        DataRow(
                          cells: [
                            DataCell(Text(
                              p['receipt_no']?.toString() ?? p['receiptNo']?.toString() ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            )),
                            DataCell(Text(
                              p['date'] != null ? Fmt.date(DateTime.tryParse(p['date'].toString())) : '—',
                              style: const TextStyle(fontSize: 12),
                            )),
                            DataCell(Text(
                              p['kind']?.toString() ?? '—',
                              style: const TextStyle(fontSize: 12),
                            )),
                            DataCell(Text(
                              p['mode']?.toString() ?? '—',
                              style: const TextStyle(fontSize: 12),
                            )),
                            DataCell(Text(
                              p['status']?.toString() ?? 'completed',
                              style: const TextStyle(fontSize: 12),
                            )),
                            DataCell(Text(
                              '₹${Fmt.money(p['amount'] is num ? p['amount'] : double.tryParse(p['amount']?.toString() ?? '0'))}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _divider(AppColors c) => Divider(height: 1, color: c.border);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.brand),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label1, this.value1, this.label2, this.value2);

  final String label1;
  final String value1;
  final String label2;
  final String value2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label1, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value1.isEmpty ? '—' : value1,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label2, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value2.isEmpty ? '—' : value2,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
