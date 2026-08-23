import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

/// Label above a control, with the red asterisk used across the reference UI.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // An empty label means "no label" — used by filter bars where the
    // placeholder text carries the meaning.
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            if (required)
              TextSpan(
                text: '* ',
                style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
              ),
            TextSpan(text: label),
          ],
        ),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: c.textSecondary,
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.required = false,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool required;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          enabled: enabled,
          onChanged: onChanged,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 40),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.required = false,
    this.hint,
    this.validator,
    this.includeAllOption = false,
    this.allLabel = S.all,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String? hint;
  final String? Function(T?)? validator;

  /// Prepends a `null` entry meaning "no filter".
  final bool includeAllOption;
  final String allLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Guard against a stale selection that is no longer in the list.
    final safeValue = value != null && items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        DropdownButtonFormField<T>(
          initialValue: safeValue,
          isExpanded: true,
          validator: validator,
          hint: hint == null
              ? null
              : Text(hint!, style: TextStyle(fontSize: 14, color: c.textMuted)),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textSecondary),
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          dropdownColor: c.surface,
          borderRadius: BorderRadius.circular(10),
          onChanged: enabled ? onChanged : null,
          items: [
            if (includeAllOption)
              DropdownMenuItem<T>(
                value: null,
                child: Text(allLabel, style: TextStyle(color: c.textSecondary)),
              ),
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ],
    );
  }
}

class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool required;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: firstDate ?? DateTime(2015),
              lastDate: lastDate ?? DateTime(DateTime.now().year + 5),
            );
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: c.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null ? '—' : Fmt.date(value),
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Debounce-free search box used on list pages.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = S.search,
    this.controller,
    this.width,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final TextEditingController? controller;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

// ---------------------------------------------------------------------------
// Responsive form layout
// ---------------------------------------------------------------------------

/// A single cell in a [FormGrid]; [span] counts grid columns.
class GridItem {
  const GridItem(this.child, {this.span = 1});
  const GridItem.full(this.child) : span = 99;

  final Widget child;
  final int span;
}

/// Lays fields out in 1 column on phones, 2 on tablets and 3 on desktop.
class FormGrid extends StatelessWidget {
  const FormGrid({
    super.key,
    required this.items,
    this.gap = 16,
    this.columnsOverride,
  });

  final List<GridItem> items;
  final double gap;
  final int? columnsOverride;

  @override
  Widget build(BuildContext context) {
    final int columns = columnsOverride ??
        context.responsive<int>(mobile: 1, tablet: 2, laptop: 3, desktop: 3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final unit = (available - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: () {
                  final span = item.span.clamp(1, columns);
                  return (unit * span + gap * (span - 1))
                      .clamp(0.0, available);
                }(),
                child: item.child,
              ),
          ],
        );
      },
    );
  }
}

/// Titled block inside a form (व्यक्तिगत जानकारी, संपर्क जानकारी …).
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: c.brand),
              const SizedBox(width: 7),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// Common input formatters.
class Fmts {
  const Fmts._();

  static final digitsOnly = FilteringTextInputFormatter.digitsOnly;
  static List<TextInputFormatter> phone() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ];
  static List<TextInputFormatter> aadhaar() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ];
  static List<TextInputFormatter> pincode() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ];
  static List<TextInputFormatter> amount() => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        LengthLimitingTextInputFormatter(10),
      ];
  static List<TextInputFormatter> otp() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ];
}
