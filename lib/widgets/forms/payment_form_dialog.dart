import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

Future<void> showPaymentFormDialog(
  BuildContext context, {
  Payment? existing,
  Member? presetMember,
}) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) =>
        PaymentFormDialog(existing: existing, presetMember: presetMember),
  );
}

class PaymentFormDialog extends ConsumerStatefulWidget {
  const PaymentFormDialog({super.key, this.existing, this.presetMember});

  final Payment? existing;
  final Member? presetMember;

  @override
  ConsumerState<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends ConsumerState<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amount;
  late final TextEditingController _reference;
  late final TextEditingController _note;

  Member? _member;
  PaymentMode _mode = PaymentMode.cash;
  PaymentStatus _status = PaymentStatus.paid;
  PaymentKind _kind = PaymentKind.contribution;
  DateTime _date = DateTime.now();
  String? _agentId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _amount = TextEditingController(
      text: p == null ? '' : p.amount.toStringAsFixed(0),
    );
    _reference = TextEditingController(text: p?.reference ?? '');
    _note = TextEditingController(text: p?.note ?? '');
    _mode = p?.mode ?? PaymentMode.cash;
    _status = p?.status ?? PaymentStatus.paid;
    _kind = p?.kind ?? PaymentKind.contribution;
    _date = p?.date ?? DateTime.now();
    _agentId = p?.agentId ?? widget.presetMember?.agentId;
    _member = widget.presetMember;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Prefill the amount from the scheme once a member is picked.
  void _onMemberPicked(Member member) {
    final yojna = ref.read(yojnaByIdProvider)[member.yojnaId];
    setState(() {
      _member = member;
      _agentId = member.agentId;
      if (_amount.text.trim().isEmpty && yojna != null) {
        _amount.text = (_kind == PaymentKind.registration
                ? yojna.registrationFee
                : yojna.contributionAmount)
            .toStringAsFixed(0);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final member = _member;
    if (member == null) {
      showToast(context, 'सदस्य चुनें', error: true);
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(paymentsProvider.notifier);
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;

    try {
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.copyWith(
            memberId: member.id,
            yojnaId: member.yojnaId,
            amount: amount,
            date: _date,
            mode: _mode,
            status: _status,
            kind: _kind,
            agentId: _agentId,
            clearAgent: _agentId == null,
            reference: _reference.text.trim(),
            note: _note.text.trim(),
          ),
        );
      } else {
        final receipt = await notifier.nextReceiptNo();
        await notifier.add(
          Payment(
            id: '',
            receiptNo: receipt,
            memberId: member.id,
            yojnaId: member.yojnaId,
            amount: amount,
            date: _date,
            mode: _mode,
            status: _status,
            kind: _kind,
            agentId: _agentId,
            reference: _reference.text.trim(),
            note: _note.text.trim(),
          ),
        );
      }

      if (!mounted) return;
      showToast(context, _isEdit ? 'Payment updated' : 'भुगतान दर्ज किया गया');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
    final yojna =
        _member == null ? null : ref.watch(yojnaByIdProvider)[_member!.yojnaId];

    return AppDialog(
      title: _isEdit ? 'Edit Payment' : S.addPayment,
      subtitle: _isEdit ? widget.existing!.receiptNo : 'भुगतान दर्ज करें',
      icon: Icons.receipt_long_outlined,
      maxWidth: 720,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancelHi),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(S.save),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MemberPickerField(
              members: members,
              selected: _member,
              onSelected: _onMemberPicked,
              onCleared: () => setState(() => _member = null),
            ),
            if (yojna != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.brand.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspaces_outline, size: 16, color: c.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${yojna.name}  ·  सहयोग ${Fmt.money(yojna.contributionAmount)}',
                        style: TextStyle(fontSize: 12.5, color: c.brand),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FormGrid(
              columnsOverride: MediaQuery.sizeOf(context).width < 680 ? 1 : 2,
              items: [
                GridItem(
                  AppDropdown<PaymentKind>(
                    label: 'Type',
                    required: true,
                    value: _kind,
                    items: PaymentKind.values,
                    itemLabel: (k) => k.label,
                    onChanged: (v) => setState(() => _kind = v ?? _kind),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: '${S.amount} (₹)',
                    required: true,
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.amount,
                  ),
                ),
                GridItem(
                  AppDateField(
                    label: S.date,
                    required: true,
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                ),
                GridItem(
                  AppDropdown<PaymentMode>(
                    label: S.mode,
                    value: _mode,
                    items: PaymentMode.values,
                    itemLabel: (m) => '${m.label} (${m.hi})',
                    onChanged: (v) => setState(() => _mode = v ?? _mode),
                  ),
                ),
                GridItem(
                  AppDropdown<PaymentStatus>(
                    label: S.status,
                    value: _status,
                    items: PaymentStatus.values,
                    itemLabel: (s) => s.label,
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ),
                GridItem(
                  AppDropdown<Agent>(
                    label: 'Collected by',
                    value: agents.firstWhereOrNull((a) => a.id == _agentId),
                    items: agents,
                    itemLabel: (a) => '${a.code} · ${a.name}',
                    includeAllOption: true,
                    allLabel: '— कोई नहीं —',
                    onChanged: (v) => setState(() => _agentId = v?.id),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Reference / UTR',
                    controller: _reference,
                    hint: 'UPI / cheque / UTR',
                  ),
                ),
                GridItem.full(
                  AppTextField(
                    label: 'Note',
                    controller: _note,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Type-ahead search over members by name, registration number or phone.
class MemberPickerField extends StatelessWidget {
  const MemberPickerField({
    super.key,
    required this.members,
    required this.selected,
    required this.onSelected,
    this.onCleared,
    this.label = 'सदस्य (Member)',
  });

  final List<Member> members;
  final Member? selected;
  final ValueChanged<Member> onSelected;
  final VoidCallback? onCleared;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (selected != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.borderStrong),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: c.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected!.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '${selected!.regNo} · ${Fmt.phone(selected!.primaryPhone)}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCleared,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Change',
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, required: true),
        Autocomplete<Member>(
          displayStringForOption: (m) => '${m.name} (${m.regNo})',
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            if (q.length < 2) return const Iterable<Member>.empty();
            return members.where((m) => m.searchIndex.contains(q)).take(30);
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'नाम / Reg No / फ़ोन से खोजें',
                prefixIcon: Icon(Icons.search, size: 18),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 42, minHeight: 40),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300, maxWidth: 520),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final m = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        onTap: () => onSelected(m),
                        title: Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${m.regNo} · ${Fmt.phone(m.primaryPhone)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
