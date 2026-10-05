import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_search_field.dart';
import 'export_menu.dart';

/// The single toolbar above every data table:
///
///   wide:     [ Search ] [Filters (2)]            [↻] [Download ▾] [Columns]
///   compact:  [ Search ........ ] [filter icon] [⋮ Refresh / Excel / PDF]
///
/// The screen decides what "open filters" does (inline panel on wide screens,
/// bottom sheet on compact ones).
class TableToolbar extends StatelessWidget {
  const TableToolbar({
    super.key,
    required this.searchHint,
    required this.onSearch,
    this.onOpenFilters,
    this.filterCount = 0,
    this.filtersOpen = false,
    this.onRefresh,
    this.export,
    this.trailing = const [],
    this.compactBreakpoint = 720,
  });

  final String searchHint;
  final ValueChanged<String> onSearch;

  /// Null hides the Filters button (screens without filters).
  final VoidCallback? onOpenFilters;
  final int filterCount;
  final bool filtersOpen;
  final VoidCallback? onRefresh;
  final ExportSpec? export;

  /// Extra wide-screen actions (e.g. the column chooser). Hidden on compact.
  final List<Widget> trailing;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth < compactBreakpoint ? _compact(context) : _wide(context),
    );
  }

  Widget _filterButton({required bool iconOnly}) {
    if (onOpenFilters == null) return const SizedBox.shrink();
    final badge = filterCount > 0 ? ' ($filterCount)' : '';
    if (iconOnly) {
      return Badge(
        isLabelVisible: filterCount > 0,
        label: Text('$filterCount'),
        child: IconButton.outlined(
          tooltip: 'Filters$badge',
          icon: const Icon(Icons.filter_list),
          onPressed: onOpenFilters,
        ),
      );
    }
    final active = filtersOpen || filterCount > 0;
    return OutlinedButton.icon(
      onPressed: onOpenFilters,
      icon: Icon(
        filtersOpen ? Icons.keyboard_arrow_up : Icons.filter_list,
        size: 18,
      ),
      label: Text('Filters$badge'),
      style: active
          ? OutlinedButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              side: const BorderSide(color: AppColors.primary),
            )
          : null,
    );
  }

  Widget _wide(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              child: AppSearchField(hint: searchHint, onChanged: onSearch),
            ),
            _filterButton(iconOnly: false),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onRefresh != null)
              IconButton.outlined(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: onRefresh,
              ),
            if (export != null) ExportMenu(spec: export!),
            ...trailing,
          ],
        ),
      ],
    );
  }

  Widget _compact(BuildContext context) {
    final spec = export;
    final canExport = spec != null && !spec.isEmpty;
    return Row(
      children: [
        Expanded(
          child: AppSearchField(hint: searchHint, onChanged: onSearch),
        ),
        if (onOpenFilters != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _filterButton(iconOnly: true),
        ],
        if (onRefresh != null || spec != null)
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'refresh':
                  onRefresh?.call();
                case 'xlsx':
                case 'pdf':
                  runExport(context, spec!, v);
              }
            },
            itemBuilder: (_) => [
              if (onRefresh != null)
                const PopupMenuItem(
                  value: 'refresh',
                  child: _MenuRow(Icons.refresh, 'Refresh'),
                ),
              if (spec != null) ...[
                PopupMenuItem(
                  value: 'xlsx',
                  enabled: canExport,
                  child: const _MenuRow(
                    Icons.table_chart_outlined,
                    'Export Excel',
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  enabled: canExport,
                  child: const _MenuRow(
                    Icons.picture_as_pdf_outlined,
                    'Export PDF',
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.md),
      Text(label),
    ],
  );
}
