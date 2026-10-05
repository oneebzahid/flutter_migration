import 'package:flutter/material.dart';

import '../storage/app_prefs.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pagination state for a list held in memory.
class PageState {
  const PageState({this.page = 1, this.pageSize = 25});

  final int page;
  final int pageSize;

  static const sizes = [10, 25, 50, 100];

  /// Restores the page size the user last chose on this screen.
  factory PageState.restore(String storageKey) {
    final saved = AppPrefs.store.getInt('pageSize.$storageKey');
    return PageState(pageSize: sizes.contains(saved) ? saved! : 25);
  }

  int pageCount(int total) => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;

  /// Page clamped to the valid range for [total] rows.
  int safePage(int total) => page.clamp(1, pageCount(total));

  List<T> slice<T>(List<T> all) {
    final p = safePage(all.length);
    final start = (p - 1) * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start.clamp(0, all.length), end);
  }

  PageState copyWith({int? page, int? pageSize}) =>
      PageState(page: page ?? this.page, pageSize: pageSize ?? this.pageSize);
}

/// "Showing 1–25 of 120", page-size picker and page buttons.
class AppPaginationBar extends StatelessWidget {
  const AppPaginationBar({
    super.key,
    required this.state,
    required this.total,
    required this.onChanged,
    this.storageKey,
  });

  final PageState state;
  final int total;
  final ValueChanged<PageState> onChanged;

  /// When set, the chosen rows-per-page is remembered for this screen.
  final String? storageKey;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final page = state.safePage(total);
    final count = state.pageCount(total);
    final start = (page - 1) * state.pageSize + 1;
    final end = (page * state.pageSize).clamp(0, total);

    final pages = <int>{
      1,
      count,
      for (var p = page - 1; p <= page + 1; p++)
        if (p >= 1 && p <= count) p,
    }.toList()..sort();

    final buttons = <Widget>[];
    for (var i = 0; i < pages.length; i++) {
      if (i > 0 && pages[i] - pages[i - 1] > 1) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('…'),
          ),
        );
      }
      final p = pages[i];
      buttons.add(
        _PageButton(
          label: '$p',
          selected: p == page,
          onTap: () => onChanged(state.copyWith(page: p)),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppSpacing.sm,
      spacing: AppSpacing.lg,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              'Showing $start–$end of $total',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rows per page',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<int>(
                  value: state.pageSize,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    for (final s in PageState.sizes)
                      DropdownMenuItem(value: s, child: Text('$s')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    if (storageKey != null) {
                      AppPrefs.store.setInt('pageSize.$storageKey', v);
                    }
                    onChanged(PageState(page: 1, pageSize: v));
                  },
                ),
              ],
            ),
          ],
        ),
        if (count > 1)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1
                    ? () => onChanged(state.copyWith(page: page - 1))
                    : null,
              ),
              ...buttons,
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: page < count
                    ? () => onChanged(state.copyWith(page: page + 1))
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Page $label',
    excludeSemantics: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
