import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

Future<void> showYojnaFormDialog(BuildContext context, {Yojna? existing}) {
  return AppDialog.show<void>(
    context: context,
    builder: (_) => YojnaFormDialog(existing: existing),
  );
}

class YojnaFormDialog extends ConsumerStatefulWidget {
  const YojnaFormDialog({super.key, this.existing});

  final Yojna? existing;

  @override
  ConsumerState<YojnaFormDialog> createState() => _YojnaFormDialogState();
}

class _YojnaFormDialogState extends ConsumerState<YojnaFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _description;
  late final TextEditingController _contribution;
  late final TextEditingController _claim;
  late final TextEditingController _registration;

  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final y = widget.existing;
    _name = TextEditingController(text: y?.name ?? '');
    _code = TextEditingController(text: y?.code ?? '');
    _description = TextEditingController(text: y?.description ?? '');
    _contribution =
        TextEditingController(text: y == null ? '' : _num(y.contributionAmount));
    _claim = TextEditingController(text: y == null ? '' : _num(y.claimAmount));
    _registration =
        TextEditingController(text: y == null ? '' : _num(y.registrationFee));
    _isActive = y?.isActive ?? true;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _description,
      _contribution,
      _claim,
      _registration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final notifier = ref.read(yojnaListProvider.notifier);

    double parse(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

    try {
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.copyWith(
            name: _name.text.trim(),
            code: _code.text.trim().toUpperCase(),
            description: _description.text.trim(),
            contributionAmount: parse(_contribution),
            claimAmount: parse(_claim),
            registrationFee: parse(_registration),
            isActive: _isActive,
          ),
        );
      } else {
        await notifier.add(
          Yojna(
            id: '',
            name: _name.text.trim(),
            code: _code.text.trim().toUpperCase(),
            description: _description.text.trim(),
            contributionAmount: parse(_contribution),
            claimAmount: parse(_claim),
            registrationFee: parse(_registration),
            isActive: _isActive,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;
      showToast(context, _isEdit ? 'योजना अपडेट की गई' : 'नई योजना बनाई गई');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _isEdit ? 'योजना संपादित करें' : 'नई योजना बनाएँ',
      subtitle: _isEdit ? widget.existing!.code : 'Create a new scheme',
      icon: Icons.workspaces_outline,
      maxWidth: 680,
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
            FormGrid(
              columnsOverride: MediaQuery.sizeOf(context).width < 680 ? 1 : 2,
              items: [
                GridItem(
                  AppTextField(
                    label: 'योजना का नाम',
                    required: true,
                    controller: _name,
                    hint: 'सुरक्षा सहयोग योजना',
                    validator: V.required,
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'कोड (Code)',
                    required: true,
                    controller: _code,
                    hint: 'SSY',
                    validator: V.required,
                  ),
                ),
                GridItem.full(
                  AppTextField(
                    label: 'विवरण (Description)',
                    controller: _description,
                    maxLines: 3,
                    hint: 'योजना का संक्षिप्त विवरण',
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'पंजीकरण शुल्क (₹)',
                    controller: _registration,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.optionalAmount,
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'प्रति सहयोग राशि (₹)',
                    required: true,
                    controller: _contribution,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.amount,
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'क्लेम राशि (₹)',
                    required: true,
                    controller: _claim,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.amount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Active', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Only active schemes appear in the member form',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
