import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

Future<void> showAgentFormDialog(BuildContext context, {Agent? existing}) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) => AgentFormDialog(existing: existing),
  );
}

class AgentFormDialog extends ConsumerStatefulWidget {
  const AgentFormDialog({super.key, this.existing});

  final Agent? existing;

  @override
  ConsumerState<AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends ConsumerState<AgentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _area;
  late final TextEditingController _district;
  late final TextEditingController _commission;

  late Set<String> _yojnaIds;
  late bool _isActive;
  late DateTime _joinDate;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _phone = TextEditingController(text: a?.phone ?? '');
    _email = TextEditingController(text: a?.email ?? '');
    _area = TextEditingController(text: a?.area ?? '');
    _district = TextEditingController(text: a?.district ?? '');
    _commission =
        TextEditingController(text: a == null ? '2' : '${a.commissionPercent}');
    _yojnaIds = {...?a?.yojnaIds};
    _isActive = a?.isActive ?? true;
    _joinDate = a?.joinDate ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _area, _district, _commission]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final notifier = ref.read(agentsProvider.notifier);

    try {
      final commission = double.tryParse(_commission.text.trim()) ?? 0;
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.copyWith(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            area: _area.text.trim(),
            district: _district.text.trim(),
            commissionPercent: commission,
            yojnaIds: _yojnaIds.toList(),
            isActive: _isActive,
            joinDate: _joinDate,
          ),
        );
      } else {
        final code = await notifier.nextCode();
        await notifier.add(
          Agent(
            id: '',
            code: code,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            area: _area.text.trim(),
            district: _district.text.trim(),
            commissionPercent: commission,
            yojnaIds: _yojnaIds.toList(),
            isActive: _isActive,
            joinDate: _joinDate,
          ),
        );
      }

      if (!mounted) return;
      showToast(context, _isEdit ? 'Agent updated' : 'Agent added');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yojnas = ref.watch(yojnaListProvider).value ?? const <Yojna>[];

    return AppDialog(
      title: _isEdit ? 'Edit Agent' : S.addAgent,
      subtitle: _isEdit ? widget.existing!.code : 'एजेंट की जानकारी दर्ज करें',
      icon: Icons.person_add_alt_rounded,
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
            FormSection(
              title: 'Agent details',
              icon: Icons.badge_outlined,
              child: FormGrid(
                columnsOverride: MediaQuery.sizeOf(context).width < 680 ? 1 : 2,
                items: [
                  GridItem(
                    AppTextField(
                      label: S.name,
                      required: true,
                      controller: _name,
                      hint: 'पूरा नाम',
                      validator: V.required,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: S.phone,
                      required: true,
                      controller: _phone,
                      hint: '98765 43210',
                      prefixIcon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: Fmts.phone(),
                      validator: V.phone,
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'agent@rudranshct.org',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? null : V.email(v),
                    ),
                  ),
                  GridItem(
                    AppTextField(
                      label: '${S.commission} (%)',
                      controller: _commission,
                      keyboardType: TextInputType.number,
                      inputFormatters: Fmts.amount(),
                      validator: V.optionalAmount,
                    ),
                  ),
                  GridItem(AppTextField(label: S.area, controller: _area)),
                  GridItem(
                    AppTextField(label: S.fldDistrict, controller: _district),
                  ),
                  GridItem(
                    AppDateField(
                      label: 'Joining date',
                      value: _joinDate,
                      onChanged: (d) => setState(() => _joinDate = d),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FormSection(
              title: 'Assigned Yojna',
              icon: Icons.workspaces_outline,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final y in yojnas)
                    FilterChip(
                      label: Text(y.name),
                      selected: _yojnaIds.contains(y.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _yojnaIds.add(y.id);
                        } else {
                          _yojnaIds.remove(y.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Active', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Inactive agents cannot be assigned to new members',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
