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

/// Shows complete member data in a human-readable table and card format,
/// displaying every detail filled in the member form with options to download
/// CSV or copy clean text.
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
  Map<String, dynamic> get _memberMap =>
      widget.data['member'] as Map<String, dynamic>? ?? {};

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

  int? get _age {
    final dob = widget.member.dob;
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  String get _aadhaarDisplay {
    final raw = _memberMap['aadhaar']?.toString() ?? widget.member.aadhaar;
    if (raw.isNotEmpty) return raw;
    if (widget.member.aadhaarLast4.isNotEmpty) {
      return 'XXXX XXXX ${widget.member.aadhaarLast4}';
    }
    return '—';
  }

  String _generateCsv() {
    final m = widget.member;
    final ageStr = _age != null ? '$_age yrs' : '—';
    final rows = <List<Object?>>[
      ['RUDRANSH CHARITABLE TRUST - COMPLETE MEMBER PROFILE'],
      ['Field', 'Value'],
      ['Registration No', m.regNo],
      ['Full Name', m.name],
      ['Father/Husband Name', m.fatherOrHusbandName],
      ['Jati', m.jati.isNotEmpty ? m.jati : '—'],
      ['Gotra', m.gotra.isNotEmpty ? m.gotra : '—'],
      ['Date of Birth', m.dob != null ? Fmt.date(m.dob) : '—'],
      ['Age', ageStr],
      ['Gender', m.gender.label],
      ['Primary Mobile', m.primaryPhone],
      ['Alternate Phone', m.altPhone.isNotEmpty ? m.altPhone : '—'],
      ['Email Address', m.email.isNotEmpty ? m.email : '—'],
      ['Aadhaar Number', _aadhaarDisplay],
      ['Village / Ward', m.village.isNotEmpty ? m.village : '—'],
      ['Tehsil', m.tehsil.isNotEmpty ? m.tehsil : '—'],
      ['District', m.district.isNotEmpty ? m.district : '—'],
      ['State', m.state.isNotEmpty ? m.state : '—'],
      ['Pincode', m.pincode.isNotEmpty ? m.pincode : '—'],
      ['Nominee (Waris) Name', m.warisName.isNotEmpty ? m.warisName : '—'],
      ['Nominee Relation', m.warisRelation.isNotEmpty ? m.warisRelation : '—'],
      ['Scheme (Yojna)', _yojnaMap['name'] ?? m.yojnaId],
      ['Scheme Code', _yojnaMap['code'] ?? '—'],
      ['Assigned Agent', _agentMap['name'] ?? 'Direct / None'],
      ['Agent Code', _agentMap['code'] ?? '—'],
      ['Joined Date', Fmt.date(m.joinDate)],
      ['Membership Status', m.status.label],
      ['Contribution Amount (INR)', '₹${m.contributionAmount}'],
      ['Member Photo Uploaded', m.photoUrl.isNotEmpty ? 'Yes' : 'No'],
      ['Member Aadhaar Front Uploaded', m.memberAadhaarFrontUrl.isNotEmpty ? 'Yes' : 'No'],
      ['Member Aadhaar Back Uploaded', m.memberAadhaarBackUrl.isNotEmpty ? 'Yes' : 'No'],
      ['Nominee Photo Uploaded', m.warisPhotoUrl.isNotEmpty ? 'Yes' : 'No'],
      ['Nominee Aadhaar Front Uploaded', m.warisAadhaarFrontUrl.isNotEmpty ? 'Yes' : 'No'],
      ['Nominee Aadhaar Back Uploaded', m.warisAadhaarBackUrl.isNotEmpty ? 'Yes' : 'No'],
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
    final ageStr = _age != null ? '$_age years' : '—';
    final buf = StringBuffer();
    buf.writeln('========================================');
    buf.writeln('RUDRANSH CHARITABLE TRUST');
    buf.writeln('COMPLETE MEMBER DATA PROFILE');
    buf.writeln('========================================');
    buf.writeln('SCHEME & ENROLLMENT:');
    buf.writeln('  Registration No : ${m.regNo}');
    buf.writeln('  Scheme (Yojna)  : ${_yojnaMap['name'] ?? m.yojnaId} (${_yojnaMap['code'] ?? ''})');
    buf.writeln('  Assigned Agent  : ${_agentMap['name'] ?? 'Direct / None'} ${_agentMap['code'] != null ? '(${_agentMap['code']})' : ''}');
    buf.writeln('  Join Date       : ${Fmt.date(m.joinDate)}');
    buf.writeln('  Member Status   : ${m.status.label}');
    buf.writeln('  Contribution    : ₹${m.contributionAmount}');
    buf.writeln('----------------------------------------');
    buf.writeln('PERSONAL DETAILS:');
    buf.writeln('  Full Name       : ${m.name}');
    buf.writeln('  Father / Husband: ${m.fatherOrHusbandName}');
    buf.writeln('  Gender          : ${m.gender.label}');
    buf.writeln('  Date of Birth   : ${m.dob != null ? Fmt.date(m.dob) : '—'} (Age: $ageStr)');
    buf.writeln('  Jati / Gotra    : ${m.jati} / ${m.gotra.isNotEmpty ? m.gotra : '—'}');
    buf.writeln('  Aadhaar Number  : $_aadhaarDisplay');
    buf.writeln('----------------------------------------');
    buf.writeln('CONTACT & ADDRESS:');
    buf.writeln('  Primary Phone   : ${m.primaryPhone}');
    buf.writeln('  Alternate Phone : ${m.altPhone.isNotEmpty ? m.altPhone : '—'}');
    buf.writeln('  Email Address   : ${m.email.isNotEmpty ? m.email : '—'}');
    buf.writeln('  Village / Ward  : ${m.village.isNotEmpty ? m.village : '—'}');
    buf.writeln('  Tehsil          : ${m.tehsil.isNotEmpty ? m.tehsil : '—'}');
    buf.writeln('  District        : ${m.district.isNotEmpty ? m.district : '—'}');
    buf.writeln('  State & PIN     : ${m.state.isNotEmpty ? m.state : '—'} - ${m.pincode.isNotEmpty ? m.pincode : '—'}');
    buf.writeln('----------------------------------------');
    buf.writeln('NOMINEE (WARISDAR):');
    buf.writeln('  Nominee Name    : ${m.warisName.isNotEmpty ? m.warisName : '—'}');
    buf.writeln('  Relation        : ${m.warisRelation.isNotEmpty ? m.warisRelation : '—'}');
    buf.writeln('----------------------------------------');
    buf.writeln('DOCUMENTS ATTACHED:');
    buf.writeln('  Member Photo    : ${m.photoUrl.isNotEmpty ? 'Attached' : 'Not Attached'}');
    buf.writeln('  Member Aadhaar  : ${(m.memberAadhaarFrontUrl.isNotEmpty || m.memberAadhaarBackUrl.isNotEmpty) ? 'Attached' : 'Not Attached'}');
    buf.writeln('  Nominee Photo   : ${m.warisPhotoUrl.isNotEmpty ? 'Attached' : 'Not Attached'}');
    buf.writeln('  Nominee Aadhaar : ${(m.warisAadhaarFrontUrl.isNotEmpty || m.warisAadhaarBackUrl.isNotEmpty) ? 'Attached' : 'Not Attached'}');
    buf.writeln('----------------------------------------');
    buf.writeln('RECEIPTS & PAYMENTS HISTORY (${_payments.length}):');
    if (_payments.isEmpty) {
      buf.writeln('  No receipts recorded.');
    } else {
      for (final p in _payments) {
        final rNo = p['receipt_no'] ?? p['receiptNo'] ?? '—';
        final d = p['date'] != null ? Fmt.date(DateTime.tryParse(p['date'].toString())) : '—';
        final kind = p['kind'] ?? '';
        final mode = p['mode'] ?? '';
        final amt = p['amount'] ?? 0;
        buf.writeln('  • Receipt #$rNo | $d | $kind | $mode | ₹$amt');
      }
      buf.writeln('  TOTAL PAID: ₹$_totalPaid');
    }
    buf.writeln('========================================');
    return buf.toString();
  }

  Future<void> _downloadCsv() async {
    final fileName = '${widget.member.regNo}_complete_data.csv';
    final saved = await downloadTextFile(fileName, _generateCsv());
    if (!mounted) return;
    if (saved) {
      showToast(context, 'Downloaded $fileName');
    } else {
      showToast(context, 'Downloading works in browser/web view.', error: true);
    }
  }

  Future<void> _copyText() async {
    final text = _generateReadableText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showToast(context, 'Complete member details copied to clipboard');
  }

  void _previewImage(String title, String url) {
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildNetworkOrMemoryImage(url),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkOrMemoryImage(String url) {
    if (url.startsWith('data:')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        );
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image_outlined, size: 48));
      }
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Icon(Icons.broken_image_outlined, size: 48),
        ),
      ),
    );
  }

  ImageProvider? _avatarImage(String url) {
    if (url.isEmpty) return null;
    try {
      if (url.startsWith('data:')) {
        return MemoryImage(base64Decode(url.split(',').last));
      }
      return NetworkImage(url);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.member;

    return AppDialog(
      title: '${S.exportData}: ${m.name}',
      subtitle: '${m.regNo} · ${_yojnaMap['name'] ?? ''}',
      maxWidth: 820,
      actions: [
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: _buildHumanTableView(c, m),
    );
  }

  Widget _buildHumanTableView(AppColors c, Member m) {
    final payments = _payments;
    final ageStr = _age != null ? '$_age yrs' : '—';
    final avatarProvider = _avatarImage(m.photoUrl);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top summary banner with Photo avatar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: m.photoUrl.isNotEmpty
                      ? () => _previewImage('Member Photo: ${m.name}', m.photoUrl)
                      : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: c.brand.withValues(alpha: 0.15),
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: c.brand,
                                ),
                              )
                            : null,
                      ),
                      if (m.photoUrl.isNotEmpty)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: c.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Reg. No: ${m.regNo}  ·  Scheme: ${_yojnaMap['name'] ?? m.yojnaId}',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
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

          // 2. Scheme & Enrollment details
          _SectionHeader(title: 'Scheme & Enrollment (योजना एवं पंजीयन विवरण)', icon: Icons.assignment_outlined),
          const SizedBox(height: 8),
          _CardContainer(
            c: c,
            children: [
              _InfoRow('Scheme (Yojna)', _yojnaMap['name']?.toString() ?? m.yojnaId, 'Scheme Code', _yojnaMap['code']?.toString() ?? '—'),
              _divider(c),
              _InfoRow('Assigned Agent', _agentMap['name']?.toString() ?? 'Direct / None', 'Agent Code', _agentMap['code']?.toString() ?? '—'),
              _divider(c),
              _InfoRow('Registration No', m.regNo, 'Joined Date', Fmt.date(m.joinDate)),
              _divider(c),
              _InfoRow('Membership Status', m.status.label, 'Contribution Amount', '₹${m.contributionAmount}'),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Personal & Identity Details
          _SectionHeader(title: 'Personal & Identity Details (व्यक्तिगत विवरण)', icon: Icons.person_outline),
          const SizedBox(height: 8),
          _CardContainer(
            c: c,
            children: [
              _InfoRow('Full Name', m.name, 'Father / Husband', m.fatherOrHusbandName),
              _divider(c),
              _InfoRow('Date of Birth', m.dob != null ? Fmt.date(m.dob) : '—', 'Age', ageStr),
              _divider(c),
              _InfoRow('Gender', m.gender.label, 'Aadhaar Number', _aadhaarDisplay),
              _divider(c),
              _InfoRow('Jati (जाति)', m.jati.isNotEmpty ? m.jati : '—', 'Gotra (गोत्र)', m.gotra.isNotEmpty ? m.gotra : '—'),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Contact & Address Details
          _SectionHeader(title: 'Contact & Address (संपर्क एवं पता)', icon: Icons.location_on_outlined),
          const SizedBox(height: 8),
          _CardContainer(
            c: c,
            children: [
              _InfoRow('Primary Mobile Phone', m.primaryPhone, 'Alternate Phone', m.altPhone.isNotEmpty ? m.altPhone : '—'),
              _divider(c),
              _InfoRow('Email Address', m.email.isNotEmpty ? m.email : '—', 'Village / Ward (ग्राम/वार्ड)', m.village.isNotEmpty ? m.village : '—'),
              _divider(c),
              _InfoRow('Tehsil (तहसील)', m.tehsil.isNotEmpty ? m.tehsil : '—', 'District (जिला)', m.district.isNotEmpty ? m.district : '—'),
              _divider(c),
              _InfoRow('State (राज्य)', m.state.isNotEmpty ? m.state : '—', 'PIN Code', m.pincode.isNotEmpty ? m.pincode : '—'),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Nominee (Warisdar) Details
          _SectionHeader(title: 'Nominee / Warisdar (वारिसदार विवरण)', icon: Icons.family_restroom_outlined),
          const SizedBox(height: 8),
          _CardContainer(
            c: c,
            children: [
              _InfoRow('Nominee Name (वारिस का नाम)', m.warisName.isNotEmpty ? m.warisName : '—', 'Relationship (संबंध)', m.warisRelation.isNotEmpty ? m.warisRelation : '—'),
            ],
          ),
          const SizedBox(height: 16),

          // 6. Uploaded Documents & Photos
          _SectionHeader(title: 'Attached Documents & Photos (संलग्न दस्तावेज़)', icon: Icons.photo_library_outlined),
          const SizedBox(height: 8),
          _CardContainer(
            c: c,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DocBadge(
                      label: 'Member Photo',
                      url: m.photoUrl,
                      icon: Icons.account_circle_outlined,
                      onTap: () => _previewImage('Member Photo', m.photoUrl),
                    ),
                    _DocBadge(
                      label: 'Member Aadhaar (Front)',
                      url: m.memberAadhaarFrontUrl,
                      icon: Icons.credit_card_outlined,
                      onTap: () => _previewImage('Member Aadhaar Front', m.memberAadhaarFrontUrl),
                    ),
                    _DocBadge(
                      label: 'Member Aadhaar (Back)',
                      url: m.memberAadhaarBackUrl,
                      icon: Icons.credit_card_outlined,
                      onTap: () => _previewImage('Member Aadhaar Back', m.memberAadhaarBackUrl),
                    ),
                    _DocBadge(
                      label: 'Nominee Photo',
                      url: m.warisPhotoUrl,
                      icon: Icons.person_pin_outlined,
                      onTap: () => _previewImage('Nominee Photo', m.warisPhotoUrl),
                    ),
                    _DocBadge(
                      label: 'Nominee Aadhaar (Front)',
                      url: m.warisAadhaarFrontUrl,
                      icon: Icons.badge_outlined,
                      onTap: () => _previewImage('Nominee Aadhaar Front', m.warisAadhaarFrontUrl),
                    ),
                    _DocBadge(
                      label: 'Nominee Aadhaar (Back)',
                      url: m.warisAadhaarBackUrl,
                      icon: Icons.badge_outlined,
                      onTap: () => _previewImage('Nominee Aadhaar Back', m.warisAadhaarBackUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 7. Payments & Receipts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(
                title: 'Payments & Receipts (${payments.length}) (जमा रसीदें)',
                icon: Icons.receipt_long_outlined,
              ),
              if (payments.isNotEmpty)
                Text(
                  'Total Paid: ₹${Fmt.money(_totalPaid)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _CardContainer(
            c: c,
            children: [
              payments.isEmpty
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
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _divider(AppColors c) => Divider(height: 1, color: c.border);
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.c, required this.children});

  final AppColors c;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _DocBadge extends StatelessWidget {
  const _DocBadge({
    required this.label,
    required this.url,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String url;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDoc = url.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasDoc ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: hasDoc ? c.surfaceMuted : c.surfaceMuted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasDoc ? c.brand.withValues(alpha: 0.4) : c.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: hasDoc ? c.brand : c.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasDoc ? FontWeight.w600 : FontWeight.normal,
                  color: hasDoc ? c.textPrimary : c.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              if (hasDoc)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 12, color: c.brand),
                      const SizedBox(width: 3),
                      Text('View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: c.brand)),
                    ],
                  ),
                )
              else
                Text(
                  'None',
                  style: TextStyle(fontSize: 10.5, color: c.textSecondary, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
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
