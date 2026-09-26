import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
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
  late final TextEditingController _shortName;
  late final TextEditingController _claim;
  late final TextEditingController _registration;

  /// Printed as योजना प्रारंभ on the membership certificate.
  DateTime? _startDate;
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
    _shortName = TextEditingController(text: y?.shortName ?? '');
    _claim = TextEditingController(text: y == null ? '' : _num(y.claimAmount));
    _registration =
        TextEditingController(text: y == null ? '' : _num(y.registrationFee));
    _startDate = y?.startDate;
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
      _shortName,
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
            shortName: _shortName.text.trim(),
            claimAmount: parse(_claim),
            registrationFee: parse(_registration),
            startDate: _startDate,
            clearStartDate: _startDate == null,
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
            shortName: _shortName.text.trim(),
            claimAmount: parse(_claim),
            registrationFee: parse(_registration),
            startDate: _startDate,
            isActive: _isActive,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;
      showToast(context, _isEdit ? 'Yojna updated' : 'Yojna created');
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
      title: _isEdit ? 'Edit Yojna' : 'New Yojna',
      subtitle: _isEdit ? widget.existing!.code : 'Create a new scheme',
      maxWidth: 680,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const ButtonSpinner()
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
                    label: 'Yojna name',
                    required: true,
                    controller: _name,
                    hint: 'e.g. Suraksha Sahyog Yojna',
                    validator: V.required,
                    // Keeps the certificate preview below current.
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Code',
                    required: true,
                    controller: _code,
                    hint: 'SSY',
                    validator: V.required,
                  ),
                ),
                GridItem.full(
                  AppTextField(
                    label: 'Description',
                    controller: _description,
                    maxLines: 3,
                    hint: 'Short description of the Yojna',
                  ),
                ),
                // प्रत्येक <this> सहयोग राशि on the membership certificate.
                GridItem(
                  AppTextField(
                    label: 'Name on certificate',
                    controller: _shortName,
                    hint: 'e.g. शादी — blank uses the Yojna name',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Registration fee (₹)',
                    controller: _registration,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.optionalAmount,
                  ),
                ),
                GridItem(
                  AppTextField(
                    label: 'Claim amount (₹)',
                    required: true,
                    controller: _claim,
                    keyboardType: TextInputType.number,
                    inputFormatters: Fmts.amount(),
                    validator: V.amount,
                  ),
                ),
                // योजना प्रारंभ on the membership certificate.
                GridItem(
                  AppDateField(
                    label: 'Scheme start date',
                    value: _startDate,
                    firstDate: DateTime(2020),
                    onChanged: (d) => setState(() => _startDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CertificateLabelPreview(
              label: Yojna.certificateLabel(
                name: _name.text,
                shortName: _shortName.text,
              ),
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

/// How the certificate's सहयोग राशि label will read, so the office sees the
/// Hindi a Hinglish name turns into and can fix it in "Name on certificate".
class _CertificateLabelPreview extends StatelessWidget {
  const _CertificateLabelPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Prints on the certificate as:  ',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
            TextSpan(
              text: '$label: ₹ ___',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
