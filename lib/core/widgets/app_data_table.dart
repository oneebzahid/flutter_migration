import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_states.dart';

/// One typed column. [cell] renders a row; [footer] optionally renders the
/// totals cell from the rows the footer covers.
class AppColumn<T> {
  const AppColumn({
    required this.id,
    required this.header,
    required this.cell,
    this.width = 120,
    this.footer,
    this.alignRight = false,
    this.semanticLabel,
    this.sortValue,
  });

  /// Stable id (used for column visibility).
  final String id;
  final String header;
  final Widget Function(BuildContext context, T row) cell;
  final double width;
  final Widget Function(BuildContext context, List<T> rows)? footer;
  final bool alignRight;
  final String? semanticLabel;

  /// Value to sort by; null makes the column non-sortable. Return lower-cased
  /// text for strings so the order is case-insensitive.
  final Comparable<Object?>? Function(T row)? sortValue;

  bool get sortable => sortValue != null;
}

/// Current sort of a table (owned by the screen).
class TableSort {
  const TableSort(this.columnId, {this.ascending = true});
  final String columnId;
  final bool ascending;

  /// Click on a header: new column → ascending, same column → flip, third click clears.
  static TableSort? next(TableSort? current, String columnId) {
    if (current == null || current.columnId != columnId) {
      return TableSort(columnId);
    }
    if (current.ascending) return TableSort(columnId, ascending: false);
    return null;
  }

  /// Sorted copy of [rows]; empty values always sort last.
  static List<T> apply<T>(
    List<T> rows,
    List<AppColumn<T>> columns,
    TableSort? sort,
  ) {
    if (sort == null) return rows;
    final col = columns.where((c) => c.id == sort.columnId).firstOrNull;
    final value = col?.sortValue;
    if (value == null) return rows;
    final out = [...rows];
    out.sort((a, b) {
      final va = value(a);
      final vb = value(b);
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      final r = va.compareTo(vb);
      return sort.ascending ? r : -r;
    });
    return out;
  }
}

/// Generic, typed data table used by every list screen.
///
/// Layout rules (project standard):
///  * The table is a fixed-height card with its own vertical scroll, a sticky
///    header and a sticky totals footer.
///  * A thick horizontal scrollbar is **always visible and pinned to the
///    bottom of the table**, so it is always on screen and users can see that
///    more columns exist. A fade + arrow on the right edge repeats the hint.
///  * The Actions column is pinned to the right, outside the horizontal scroll.
///  * Light visual weight: pale header, hairline row dividers, no zebra.
///
/// Pagination is separate (`AppPaginationBar`); [rows] are the rows to render.
/// Selection state is owned by the caller.
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.rowKey,
    this.loading = false,
    this.loadingMessage = 'Loading…',
    this.emptyTitle = 'No data',
    this.emptyMessage,
    this.errorMessage,
    this.onRetry,
    this.selectedKeys,
    this.allSelected = false,
    this.someSelected = false,
    this.onToggleRow,
    this.onToggleAll,
    this.rowActions,
    this.actionsWidth = 100,
    this.footerLabel,
    this.footerRows,
    this.rowColor,
    this.cardBuilder,
    this.compactBreakpoint = 700,
    this.maxHeight,
    this.sort,
    this.onSort,
  });

  final List<AppColumn<T>> columns;
  final List<T> rows;
  final String Function(T row) rowKey;

  final bool loading;
  final String loadingMessage;
  final String emptyTitle;
  final String? emptyMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// Selection (omit [selectedKeys] for a non-selectable table).
  final Set<String>? selectedKeys;
  final bool allSelected;
  final bool someSelected;
  final void Function(T row)? onToggleRow;
  final void Function(bool selectAll)? onToggleAll;

  final Widget Function(BuildContext context, T row)? rowActions;
  final double actionsWidth;

  /// Sticky totals row under the body.
  final String? footerLabel;
  final List<T>? footerRows;

  final Color? Function(T row, int index)? rowColor;

  /// Narrow-screen alternative (a card per row). If null the table scrolls
  /// horizontally at every width.
  final Widget Function(BuildContext context, T row)? cardBuilder;
  final double compactBreakpoint;

  /// Cap for the table height; defaults to ~62% of the screen height.
  final double? maxHeight;

  /// Sorting: the screen applies [TableSort.apply] to its rows; the table only
  /// shows the arrow and reports header clicks.
  final TableSort? sort;
  final void Function(String columnId)? onSort;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  static const double _checkW = 44;
  static const double _headerH = 44;
  static const double _rowH = 56;
  static const double _footerH = 48;

  /// Room reserved at the bottom for the always-visible scrollbar.
  static const double _barH = 14;

  final _h = ScrollController();
  final _vBody = ScrollController();
  final _vActions = ScrollController();
  bool _syncing = false;
  bool _moreToRight = false;

  bool get _selectable => widget.selectedKeys != null;

  @override
  void initState() {
    super.initState();
    _vBody.addListener(() => _sync(_vBody, _vActions));
    _vActions.addListener(() => _sync(_vActions, _vBody));
    _h.addListener(_updateHint);
  }

  @override
  void dispose() {
    _h.dispose();
    _vBody.dispose();
    _vActions.dispose();
    super.dispose();
  }

  /// Keeps the pinned Actions column vertically in step with the body.
  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if ((to.offset - target).abs() > 0.5) {
      _syncing = true;
      to.jumpTo(target);
      _syncing = false;
    }
  }

  void _updateHint() {
    if (!mounted || !_h.hasClients || !_h.position.hasContentDimensions) return;
    final more = _h.offset < _h.position.maxScrollExtent - 4;
    if (more != _moreToRight) setState(() => _moreToRight = more);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return _TableSkeleton(
        columns: widget.columns.length.clamp(3, 7),
        label: widget.loadingMessage,
      );
    }
    if (widget.errorMessage != null) {
      return SizedBox(
        height: 220,
        child: AppErrorState(
          message: widget.errorMessage,
          onRetry: widget.onRetry,
        ),
      );
    }
    if (widget.rows.isEmpty) {
      return SizedBox(
        height: 220,
        child: AppEmptyState(
          title: widget.emptyTitle,
          message: widget.emptyMessage,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        if (widget.cardBuilder != null &&
            c.maxWidth < widget.compactBreakpoint) {
          return Column(
            children: [
              for (final r in widget.rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: widget.cardBuilder!(context, r),
                ),
            ],
          );
        }
        return _table(context, c.maxWidth);
      },
    );
  }

  Widget _table(BuildContext context, double available) {
    final cols = widget.columns;
    final pinned = widget.rowActions != null ? widget.actionsWidth : 0.0;
    final scrollAvailable = available - pinned - 2; // 2 = card border
    final contentW =
        cols.fold<double>(0, (s, c) => s + _colW(c)) +
        (_selectable ? _checkW : 0);
    final width = contentW < scrollAvailable ? scrollAvailable : contentW;
    // Spare room goes to the last data column.
    final extra = width - contentW;

    final hasFooter = widget.footerRows != null;
    final contentHeight =
        _headerH +
        widget.rows.length * _rowH +
        (hasFooter ? _footerH : 0) +
        _barH;
    final cap =
        widget.maxHeight ??
        (MediaQuery.sizeOf(context).height * 0.62).clamp(380.0, 760.0);
    final height = contentHeight < cap ? contentHeight : cap;

    // Re-evaluate the "more columns" hint once layout has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHint());

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thickness: const WidgetStatePropertyAll(10),
                    radius: const Radius.circular(6),
                    thumbVisibility: const WidgetStatePropertyAll(true),
                    trackVisibility: const WidgetStatePropertyAll(true),
                    thumbColor: WidgetStatePropertyAll(
                      AppColors.textDisabled.withValues(alpha: 0.9),
                    ),
                    trackColor: const WidgetStatePropertyAll(
                      AppColors.surfaceMuted,
                    ),
                    trackBorderColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                  child: Scrollbar(
                    controller: _h,
                    child: SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            _header(context, extra),
                            Expanded(
                              child: ListView.builder(
                                controller: _vBody,
                                itemExtent: _rowH,
                                itemCount: widget.rows.length,
                                itemBuilder: (c, i) =>
                                    _row(c, widget.rows[i], i, extra),
                              ),
                            ),
                            if (hasFooter) _footer(context, extra),
                            const SizedBox(height: _barH),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // "More columns →" hint at the right edge.
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: _barH,
                  width: 44,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _moreToRight ? 1 : 0,
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.surface.withValues(alpha: 0),
                              AppColors.surface,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.rowActions != null) _actionsColumn(context),
        ],
      ),
    );
  }

  /// A column is never narrower than its header text (plus padding and the
  /// sort arrow), so headers are not cut off.
  double _colW(AppColumn<T> c) {
    final headerW =
        c.header.length * 7.6 + 2 * AppSpacing.lg + (c.sortable ? 22 : 0);
    return headerW > c.width ? headerW : c.width;
  }

  double _w(AppColumn<T> c, int idx, double extra) =>
      idx == widget.columns.length - 1 ? _colW(c) + extra : _colW(c);

  Widget _header(BuildContext context, double extra) {
    final t = Theme.of(context).textTheme;
    final style = t.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      letterSpacing: 0.6,
    );
    return Container(
      height: _headerH,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_selectable)
            SizedBox(
              width: _checkW,
              child: Semantics(
                label: 'Select all rows',
                child: Checkbox(
                  tristate: true,
                  value: widget.allSelected
                      ? true
                      : (widget.someSelected ? null : false),
                  onChanged: (_) =>
                      widget.onToggleAll?.call(!widget.allSelected),
                  activeColor: AppColors.primary,
                ),
              ),
            ),
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              width: _w(widget.columns[i], i, extra),
              child: _headerCell(widget.columns[i], style),
            ),
        ],
      ),
    );
  }

  Widget _headerCell(AppColumn<T> col, TextStyle? style) {
    final active = widget.sort?.columnId == col.id;
    final asc = widget.sort?.ascending ?? true;
    final label = Text(
      col.header.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: active ? style?.copyWith(color: AppColors.textPrimary) : style,
    );
    final content = Row(
      mainAxisAlignment: col.alignRight
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        if (col.sortable) ...[
          const SizedBox(width: 2),
          Icon(
            active
                ? (asc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: active ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ],
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: content,
    );
    if (!col.sortable || widget.onSort == null) return padded;
    return Semantics(
      button: true,
      label: 'Sort by ${col.header}',
      sortKey: null,
      excludeSemantics: true,
      child: InkWell(onTap: () => widget.onSort!(col.id), child: padded),
    );
  }

  Color _rowBg(T row, int index) {
    final custom = widget.rowColor?.call(row, index);
    if (custom != null) return custom;
    final selected = widget.selectedKeys?.contains(widget.rowKey(row)) ?? false;
    return selected
        ? AppColors.infoSoft.withValues(alpha: 0.45)
        : AppColors.surface;
  }

  static const _rowBorder = BoxDecoration(
    border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
  );

  Widget _row(BuildContext context, T row, int index, double extra) {
    final selected = widget.selectedKeys?.contains(widget.rowKey(row)) ?? false;
    return Container(
      decoration: _rowBorder.copyWith(color: _rowBg(row, index)),
      child: Row(
        children: [
          if (_selectable)
            SizedBox(
              width: _checkW,
              child: Checkbox(
                value: selected,
                onChanged: (_) => widget.onToggleRow?.call(row),
                activeColor: AppColors.primary,
              ),
            ),
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              width: _w(widget.columns[i], i, extra),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: widget.columns[i].alignRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: widget.columns[i].cell(context, row),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, double extra) {
    final t = Theme.of(context).textTheme;
    final fr = widget.footerRows!;
    // The label spans every column before the first one that has a footer.
    var firstFooter = widget.columns.indexWhere((c) => c.footer != null);
    if (firstFooter < 0) firstFooter = widget.columns.length;
    final labelW =
        (_selectable ? _checkW : 0) +
        widget.columns
            .take(firstFooter)
            .fold<double>(0, (s, c) => s + _colW(c));
    return Container(
      height: _footerH,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                (widget.footerLabel ?? 'Totals').toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          for (var i = firstFooter; i < widget.columns.length; i++)
            SizedBox(
              width: _w(widget.columns[i], i, extra),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child:
                    widget.columns[i].footer?.call(context, fr) ??
                    const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionsColumn(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasFooter = widget.footerRows != null;
    return Container(
      width: widget.actionsWidth,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            height: _headerH,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              'ACTIONS',
              style: t.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _vActions,
              itemExtent: _rowH,
              itemCount: widget.rows.length,
              itemBuilder: (c, i) => Container(
                alignment: Alignment.center,
                decoration: _rowBorder.copyWith(
                  color: _rowBg(widget.rows[i], i),
                ),
                child: widget.rowActions!(c, widget.rows[i]),
              ),
            ),
          ),
          if (hasFooter)
            Container(
              height: _footerH,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
            ),
          const SizedBox(height: _barH),
        ],
      ),
    );
  }
}

/// Placeholder rows shown while data loads (calmer than a lone spinner, and
/// the screen keeps its shape). Pulses gently.
class _TableSkeleton extends StatefulWidget {
  const _TableSkeleton({required this.columns, required this.label});

  final int columns;
  final String label;

  @override
  State<_TableSkeleton> createState() => _TableSkeletonState();
}

class _TableSkeletonState extends State<_TableSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                height: AppDimensions.tableHeaderHeight,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
              ),
              for (var r = 0; r < 6; r++)
                SizedBox(
                  height: AppDimensions.tableRowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.columns; i++) ...[
                          Expanded(
                            flex: i == 0 ? 2 : 3,
                            child: Container(
                              height: 12,
                              margin: const EdgeInsets.only(
                                right: AppSpacing.xl,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
