import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import 'primitives.dart';

/// One column of a [ResponsiveTable].
class TableCol<T> {
  const TableCol({
    required this.label,
    required this.cell,
    this.width,
    this.flex = 1,
    this.minWidth = 110,
    this.numeric = false,
    this.hideBelow,
    this.text,
  });

  final String label;

  /// Rendered cell content.
  final Widget Function(BuildContext context, T row) cell;

  /// Plain-text projection, used by the mobile card layout and CSV export.
  final String Function(T row)? text;

  /// Fixed width; when null the column shares leftover space by [flex].
  final double? width;
  final int flex;
  final double minWidth;
  final bool numeric;

  /// Hide the column when the screen is narrower than this size.
  final ScreenSize? hideBelow;

  double get resolvedMinWidth => width ?? minWidth;

  bool visibleAt(ScreenSize size) {
    if (hideBelow == null) return true;
    return size.index >= hideBelow!.index;
  }
}

/// Table that turns into a stack of cards on phones and scrolls horizontally
/// when the columns cannot fit the viewport.
class ResponsiveTable<T> extends StatefulWidget {
  const ResponsiveTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.rowActions,
    this.emptyMessage = S.noResults,
    this.emptyIcon = Icons.inbox_outlined,
    this.pageSize = 12,
    this.paginate = true,
    this.mobileTitle,
    this.mobileSubtitle,
    this.mobileLeading,
    this.mobileTrailing,
    this.rowKey,
  });

  final List<TableCol<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;

  /// Trailing action widgets rendered in a pinned right-hand column.
  final Widget Function(BuildContext context, T row)? rowActions;

  final String emptyMessage;
  final IconData emptyIcon;
  final int pageSize;
  final bool paginate;

  // Mobile card configuration.
  final String Function(T row)? mobileTitle;
  final String Function(T row)? mobileSubtitle;
  final Widget Function(BuildContext context, T row)? mobileLeading;
  final Widget Function(BuildContext context, T row)? mobileTrailing;

  final Object Function(T row)? rowKey;

  @override
  State<ResponsiveTable<T>> createState() => _ResponsiveTableState<T>();
}

class _ResponsiveTableState<T> extends State<ResponsiveTable<T>> {
  int _page = 0;
  final _horizontal = ScrollController();

  @override
  void didUpdateWidget(covariant ResponsiveTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length != oldWidget.rows.length) {
      final maxPage = _maxPage;
      if (_page > maxPage) _page = maxPage;
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  int get _maxPage => widget.paginate
      ? ((widget.rows.length - 1) ~/ widget.pageSize).clamp(0, 1 << 30)
      : 0;

  List<T> get _visibleRows {
    if (!widget.paginate) return widget.rows;
    final start = _page * widget.pageSize;
    if (start >= widget.rows.length) return const [];
    return widget.rows.sublist(
      start,
      (start + widget.pageSize).clamp(0, widget.rows.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return EmptyState(message: widget.emptyMessage, icon: widget.emptyIcon);
    }

    final body = context.isMobile ? _buildCards(context) : _buildTable(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        if (widget.paginate && widget.rows.length > widget.pageSize)
          _Pager(
            page: _page,
            maxPage: _maxPage,
            total: widget.rows.length,
            pageSize: widget.pageSize,
            onChanged: (p) => setState(() => _page = p),
          ),
      ],
    );
  }

  // ---- Desktop / tablet --------------------------------------------------

  Widget _buildTable(BuildContext context) {
    final size = context.screenSize;
    final cols =
        widget.columns.where((c) => c.visibleAt(size)).toList(growable: false);
    const actionsWidth = 108.0;

    final minWidth = cols.fold<double>(0, (sum, c) => sum + c.resolvedMinWidth) +
        (widget.rowActions != null ? actionsWidth : 0) +
        24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = constraints.maxWidth >= minWidth;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerRow(context, cols, fits, actionsWidth),
            for (final row in _visibleRows)
              _dataRow(context, cols, row, fits, actionsWidth),
          ],
        );

        if (fits) return content;

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(width: minWidth, child: content),
          ),
        );
      },
    );
  }

  Widget _headerRow(
    BuildContext context,
    List<TableCol<T>> cols,
    bool fits,
    double actionsWidth,
  ) {
    final c = context.colors;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: c.textSecondary,
      letterSpacing: 0.2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (final col in cols)
            _cellSlot(
              col: col,
              fits: fits,
              child: Text(
                col.label,
                style: style,
                overflow: TextOverflow.ellipsis,
                textAlign: col.numeric ? TextAlign.right : TextAlign.left,
              ),
            ),
          if (widget.rowActions != null)
            SizedBox(
              width: actionsWidth,
              child: Text(S.actions, style: style, textAlign: TextAlign.right),
            ),
        ],
      ),
    );
  }

  Widget _dataRow(
    BuildContext context,
    List<TableCol<T>> cols,
    T row,
    bool fits,
    double actionsWidth,
  ) {
    final c = context.colors;
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          for (final col in cols)
            _cellSlot(
              col: col,
              fits: fits,
              child: Align(
                alignment:
                    col.numeric ? Alignment.centerRight : Alignment.centerLeft,
                child: col.cell(context, row),
              ),
            ),
          if (widget.rowActions != null)
            SizedBox(
              width: actionsWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: widget.rowActions!(context, row),
              ),
            ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: widget.onRowTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onRowTap!(row),
                hoverColor: c.surfaceMuted,
                child: inner,
              ),
            ),
    );
  }

  Widget _cellSlot({
    required TableCol<T> col,
    required bool fits,
    required Widget child,
  }) {
    final padded = Padding(
      padding: const EdgeInsets.only(right: 12),
      child: child,
    );
    if (col.width != null) return SizedBox(width: col.width, child: padded);
    if (!fits) return SizedBox(width: col.minWidth, child: padded);
    return Expanded(flex: col.flex, child: padded);
  }

  // ---- Mobile ------------------------------------------------------------

  Widget _buildCards(BuildContext context) {
    final c = context.colors;
    final cols = widget.columns;

    return Column(
      children: [
        for (final row in _visibleRows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onRowTap == null
                    ? null
                    : () => widget.onRowTap!(row),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.mobileLeading != null) ...[
                            widget.mobileLeading!(context, row),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.mobileTitle?.call(row) ??
                                      cols.first.text?.call(row) ??
                                      '',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                if (widget.mobileSubtitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.mobileSubtitle!(row),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.mobileTrailing != null)
                            widget.mobileTrailing!(context, row),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 18,
                        runSpacing: 9,
                        children: [
                          for (final col in cols.skip(1))
                            if (col.text != null)
                              _MobileField(
                                label: col.label,
                                value: col.text!(row),
                              )
                            else
                              _MobileField.widget(
                                label: col.label,
                                child: col.cell(context, row),
                              ),
                        ],
                      ),
                      if (widget.rowActions != null) ...[
                        const SizedBox(height: 6),
                        Divider(color: c.border, height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: widget.rowActions!(context, row),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MobileField extends StatelessWidget {
  const _MobileField({required this.label, required this.value})
      : child = null;

  const _MobileField.widget({required this.label, required this.child})
      : value = null;

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: c.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          child ??
              Text(
                value!.isEmpty ? '—' : value!,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.maxPage,
    required this.total,
    required this.pageSize,
    required this.onChanged,
  });

  final int page;
  final int maxPage;
  final int total;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final start = page * pageSize + 1;
    final end = ((page + 1) * pageSize).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            'Showing $start–$end of $total',
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: page > 0 ? () => onChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  '${page + 1} / ${maxPage + 1}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: page < maxPage ? () => onChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
