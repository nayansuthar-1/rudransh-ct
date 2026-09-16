import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
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
    this.showOnMobile = true,
  });

  final String label;

  /// Rendered cell content.
  final Widget Function(BuildContext context, T row) cell;

  /// Plain-text projection, used by the mobile list layout.
  final String Function(T row)? text;

  /// Fixed width; when null the column shares leftover space by [flex].
  final double? width;
  final int flex;
  final double minWidth;
  final bool numeric;

  /// Hide the column when the screen is narrower than this size.
  final ScreenSize? hideBelow;

  /// Set false when the phone layout already shows this value in the row's
  /// title or subtitle.
  final bool showOnMobile;

  double get resolvedMinWidth => width ?? minWidth;

  bool visibleAt(ScreenSize size) {
    if (hideBelow == null) return true;
    return size.index >= hideBelow!.index;
  }
}

/// Table that becomes a divided list on phones and scrolls horizontally when
/// its columns cannot fit. Place it inside an [AppCard].
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
    this.mobileTrailing,
    this.rowKey,
    this.totalCount,
    this.page,
    this.onPageChanged,
    this.busy = false,
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

  // Phone list configuration.
  final String Function(T row)? mobileTitle;
  final String Function(T row)? mobileSubtitle;
  final Widget Function(BuildContext context, T row)? mobileTrailing;

  final Object Function(T row)? rowKey;

  // Server-side paging: when [onPageChanged] is set, [rows] is already the
  // current page, [page] is its zero-based index and [totalCount] the number
  // of rows across all pages.
  final int? totalCount;
  final int? page;
  final ValueChanged<int>? onPageChanged;

  /// Shows a thin progress bar while a new page or filter result loads.
  final bool busy;

  @override
  State<ResponsiveTable<T>> createState() => _ResponsiveTableState<T>();
}

class _ResponsiveTableState<T> extends State<ResponsiveTable<T>> {
  int _page = 0;
  final _horizontal = ScrollController();

  bool get _remote => widget.onPageChanged != null;

  int get _total =>
      _remote ? (widget.totalCount ?? widget.rows.length) : widget.rows.length;

  int get _currentPage => _remote ? (widget.page ?? 0) : _page;

  @override
  void didUpdateWidget(covariant ResponsiveTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_remote && widget.rows.length != oldWidget.rows.length) {
      final maxPage = _maxPage;
      if (_page > maxPage) _page = maxPage;
    }
  }

  void _changePage(int page) {
    if (_remote) {
      widget.onPageChanged!(page);
    } else {
      setState(() => _page = page);
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  int get _maxPage => widget.paginate
      ? ((_total - 1) ~/ widget.pageSize).clamp(0, 1 << 30)
      : 0;

  List<T> get _visibleRows {
    if (!widget.paginate || _remote) return widget.rows;
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
      // A delete can empty the last server page; step back to the new last one.
      if (_remote && _total > 0 && _currentPage > _maxPage) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.onPageChanged!(_maxPage));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BusyBar(visible: widget.busy),
          EmptyState(message: widget.emptyMessage, icon: widget.emptyIcon),
        ],
      );
    }

    final body = context.isMobile ? _buildList(context) : _buildTable(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BusyBar(visible: widget.busy),
        body,
        if (widget.paginate && _total > widget.pageSize)
          _Pager(
            page: _currentPage,
            maxPage: _maxPage,
            total: _total,
            pageSize: widget.pageSize,
            onChanged: _changePage,
          ),
      ],
    );
  }

  // ---- Tablet and up -----------------------------------------------------

  Widget _buildTable(BuildContext context) {
    final size = context.screenSize;
    final cols =
        widget.columns.where((c) => c.visibleAt(size)).toList(growable: false);
    const actionsWidth = 92.0;
    const hPad = 16.0;

    final minWidth = cols.fold<double>(0, (sum, c) => sum + c.resolvedMinWidth) +
        (widget.rowActions != null ? actionsWidth : 0) +
        hPad * 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = constraints.maxWidth >= minWidth;
        final rows = _visibleRows;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerRow(context, cols, fits, actionsWidth, hPad),
            for (var i = 0; i < rows.length; i++)
              _dataRow(
                context,
                cols,
                rows[i],
                fits,
                actionsWidth,
                hPad,
                last: i == rows.length - 1,
              ),
          ],
        );

        if (fits) return content;

        return Scrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
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
    double hPad,
  ) {
    final c = context.colors;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: c.textSecondary,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: Space.md),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: col.numeric ? TextAlign.right : TextAlign.left,
              ),
            ),
          if (widget.rowActions != null) SizedBox(width: actionsWidth),
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
    double hPad, {
    required bool last,
  }) {
    final c = context.colors;
    final inner = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
        child: Row(
          children: [
            for (final col in cols)
              _cellSlot(
                col: col,
                fits: fits,
                child: Align(
                  alignment: col.numeric
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 13.5,
                      color: c.textPrimary,
                    ),
                    child: col.cell(context, row),
                  ),
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
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(row),
          hoverColor: c.hover,
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
      padding: EdgeInsets.only(
        right: 16,
        left: col.numeric ? 8 : 0,
      ),
      child: child,
    );
    if (col.width != null) return SizedBox(width: col.width, child: padded);
    if (!fits) return SizedBox(width: col.minWidth, child: padded);
    return Expanded(flex: col.flex, child: padded);
  }

  // ---- Phones ------------------------------------------------------------

  Widget _buildList(BuildContext context) {
    final c = context.colors;
    final fields = widget.columns.skip(1).where((col) => col.showOnMobile);
    final rows = _visibleRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              border: i == rows.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: c.border)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onRowTap == null
                    ? null
                    : () => widget.onRowTap!(rows[i]),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.md,
                    Space.sm,
                    Space.lg,
                  ),
                  child: _listItem(context, rows[i], fields),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _listItem(BuildContext context, T row, Iterable<TableCol<T>> fields) {
    final c = context.colors;
    final title = widget.mobileTitle?.call(row) ??
        widget.columns.first.text?.call(row) ??
        '';
    final subtitle = widget.mobileSubtitle?.call(row);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.mobileTrailing != null) ...[
              const SizedBox(width: 8),
              widget.mobileTrailing!(context, row),
            ],
            if (widget.rowActions != null)
              widget.rowActions!(context, row)
            else
              const SizedBox(width: 8),
          ],
        ),
        if (fields.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = Space.lg;
                final half = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: Space.md,
                  children: [
                    for (final col in fields)
                      SizedBox(
                        width: half,
                        child: _MobileField(
                          label: col.label,
                          child: col.text != null
                              ? Text(
                                  col.text!(row).isEmpty
                                      ? '—'
                                      : col.text!(row),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: c.textPrimary,
                                  ),
                                )
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: col.cell(context, row),
                                ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MobileField extends StatelessWidget {
  const _MobileField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: c.textMuted),
        ),
        const SizedBox(height: 2),
        child,
      ],
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

    ButtonStyle square() => OutlinedButton.styleFrom(
          minimumSize: const Size(34, 34),
          fixedSize: const Size(34, 34),
          padding: EdgeInsets.zero,
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.md, Space.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$start–$end of $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontFeatures: kTabular,
              ),
            ),
          ),
          Text(
            'Page ${page + 1} of ${maxPage + 1}',
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontFeatures: kTabular,
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Previous',
            child: OutlinedButton(
              onPressed: page > 0 ? () => onChanged(page - 1) : null,
              style: square(),
              child: const Icon(Icons.chevron_left, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Next',
            child: OutlinedButton(
              onPressed: page < maxPage ? () => onChanged(page + 1) : null,
              style: square(),
              child: const Icon(Icons.chevron_right, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2px progress line; keeps its height when idle so the table never jumps.
class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: visible
          ? const LinearProgressIndicator(minHeight: 2)
          : const SizedBox.shrink(),
    );
  }
}
