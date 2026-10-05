import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class ActiveFilter {
  const ActiveFilter(this.label, this.onClear);
  final String label;
  final VoidCallback onClear;
}

/// "Brand: Garrett ✕  Status: In Stock ✕  Clear all" — shows what is filtering
/// the table right now. Renders nothing when there are no active filters.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.filters,
    required this.onClearAll,
  });

  final List<ActiveFilter> filters;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in filters)
          InputChip(
            label: Text(f.label, overflow: TextOverflow.ellipsis),
            visualDensity: VisualDensity.compact,
            backgroundColor: AppColors.surfaceMuted,
            side: BorderSide.none,
            deleteIcon: const Icon(Icons.close, size: 16),
            deleteButtonTooltipMessage: 'Remove filter',
            onDeleted: f.onClear,
          ),
        TextButton.icon(
          onPressed: onClearAll,
          icon: const Icon(Icons.close, size: 16, color: AppColors.error),
          label: const Text(
            'Clear all',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

/// Compact text for a multi-select group: `Brand: Garrett` / `Brand: 3 selected`.
String filterLabel(String name, Iterable<String> values) {
  final v = values.toList();
  if (v.length <= 2) return '$name: ${v.join(', ')}';
  return '$name: ${v.length} selected';
}
