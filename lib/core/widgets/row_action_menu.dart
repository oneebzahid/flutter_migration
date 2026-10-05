import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// One labelled entry in a [RowActionMenu].
class RowMenuItem {
  const RowMenuItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.danger = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Destructive entries are red and separated from the others.
  final bool danger;
  final bool enabled;
}

/// Three-dot (⋮) menu for a table row. Muted at rest, so a column of them
/// stays light; opens a menu with labelled items (icon + text).
class RowActionMenu extends StatelessWidget {
  const RowActionMenu({
    super.key,
    required this.items,
    this.tooltip = 'Actions',
  });

  final List<RowMenuItem> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    // Safe items first, destructive ones last under a divider.
    final normal = [
      for (final i in items)
        if (!i.danger) i,
    ];
    final danger = [
      for (final i in items)
        if (i.danger) i,
    ];
    final ordered = [...normal, ...danger];

    return PopupMenuButton<int>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (i) => ordered[i].onSelected(),
      itemBuilder: (context) => [
        for (var i = 0; i < ordered.length; i++) ...[
          if (ordered[i].danger && i > 0 && !ordered[i - 1].danger)
            const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: i,
            enabled: ordered[i].enabled,
            child: Row(
              children: [
                Icon(
                  ordered[i].icon,
                  size: 18,
                  color: ordered[i].danger
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  ordered[i].label,
                  style: TextStyle(
                    color: ordered[i].danger
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
