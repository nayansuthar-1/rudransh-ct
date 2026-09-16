import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// Label above a control; required fields get a quiet asterisk.
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
            TextSpan(text: label),
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: c.danger)),
          ],
        ),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          height: 1.3,
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
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 17),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 38, minHeight: 38),
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
          isDense: true,
          validator: validator,
          hint: hint == null
              ? null
              : Text(hint!, style: TextStyle(fontSize: 14, color: c.textMuted)),
          icon: Icon(Icons.unfold_more_rounded, size: 17, color: c.textMuted),
          style: TextStyle(
            fontSize: 14,
            color: c.textPrimary,
            fontFamily: kFontFamily,
            fontFamilyFallback: kFontFallback,
          ),
          dropdownColor: c.surface,
          borderRadius: BorderRadius.circular(Radii.panel),
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
          borderRadius: BorderRadius.circular(Radii.control),
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
                Expanded(
                  child: Text(
                    value == null ? '—' : Fmt.date(value),
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 15, color: c.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Search box used on list pages.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = S.search,
    this.value,
    this.width,
  });

  final ValueChanged<String> onChanged;
  final String hint;

  /// Current query held in app state. When it changes elsewhere (the top-bar
  /// search) the box updates to match.
  final String? value;
  final double? width;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != null && value != _controller.text) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    final width = widget.width;
    final field = SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

/// Compact filter button — "Status: Paid ▾" — that opens a menu. Filter bars
/// use these instead of full-width dropdowns so they wrap cleanly on phones.
class FilterMenu<T> extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.allLabel = S.all,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = value != null && items.contains(value);

    return PopupMenuButton<_Choice<T>>(
      tooltip: label,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 180, maxHeight: 420),
      onSelected: (choice) => onChanged(choice.value),
      itemBuilder: (context) => [
        _item(context, _Choice<T>(null), allLabel, !active),
        const PopupMenuDivider(height: 9),
        for (final item in items)
          _item(context, _Choice<T>(item), itemLabel(item), item == value),
      ],
      child: FilterButtonFrame(
        active: active,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: active ? '$label: ' : label,
                style: TextStyle(
                  color: active ? c.onBrandSoft : c.textPrimary,
                  fontWeight: active ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
              if (active)
                TextSpan(
                  text: itemLabel(value as T),
                  style: TextStyle(
                    color: c.onBrandSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  PopupMenuItem<_Choice<T>> _item(
    BuildContext context,
    _Choice<T> choice,
    String text,
    bool selected,
  ) {
    final c = context.colors;
    return PopupMenuItem<_Choice<T>>(
      value: choice,
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: c.textPrimary),
            ),
          ),
          if (selected) Icon(Icons.check, size: 16, color: c.brand),
        ],
      ),
    );
  }
}

/// Wraps a filter value so "All" (null) can be told apart from a dismissed
/// menu, which PopupMenuButton reports as null too.
class _Choice<T> {
  const _Choice(this.value);
  final T? value;
}

/// The 36px bordered frame shared by [FilterMenu] and one-off filter buttons.
class FilterButtonFrame extends StatelessWidget {
  const FilterButtonFrame({
    super.key,
    required this.child,
    this.active = false,
    this.icon = Icons.keyboard_arrow_down_rounded,
  });

  final Widget child;
  final bool active;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.only(left: Space.md, right: Space.sm),
      decoration: BoxDecoration(
        color: active ? c.brandSoft : c.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: active ? c.brandSoft : c.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: active ? c.onBrandSoft : c.textPrimary,
              ),
              child: child,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 18, color: active ? c.onBrandSoft : c.textMuted),
        ],
      ),
    );
  }
}

/// Search box plus filter buttons in one wrapping row.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.search,
    this.filters = const [],
    this.onClear,
  });

  final Widget search;
  final List<Widget> filters;

  /// Shown as "Clear" when set.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final extras = [
      ...filters,
      if (onClear != null)
        TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('Clear'),
        ),
    ];

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          if (extras.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: extras),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [SizedBox(width: 320, child: search), ...extras],
    );
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

/// Titled block inside a form (Personal details, Contact details …).
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: Space.sm),
        Divider(color: c.border, height: 1),
        const SizedBox(height: Space.lg),
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
