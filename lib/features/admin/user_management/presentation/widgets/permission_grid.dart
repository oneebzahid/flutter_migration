import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../domain/entities/screen_catalog.dart';

/// Group-by-group screen permission picker. Controlled: the owner keeps the
/// selected set and handles [onToggle] / [onToggleGroup].
class PermissionGrid extends StatelessWidget {
  const PermissionGrid({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
    this.enabled = true,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<ScreenGroup> onToggleGroup;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final group in allScreenGroups)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _GroupCard(
              group: group,
              selected: selected,
              onToggle: onToggle,
              onToggleGroup: onToggleGroup,
              enabled: enabled,
            ),
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
    required this.enabled,
  });

  final ScreenGroup group;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<ScreenGroup> onToggleGroup;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final count = group.screens.where(selected.contains).length;
    final all = count == group.screens.length;
    final tristate = count > 0 && !all;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: count > 0
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: enabled ? () => onToggleGroup(group) : null,
            child: Container(
              color: AppColors.surfaceMuted,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Semantics(
                    label: 'Select all in ${group.title}',
                    child: Checkbox(
                      tristate: true,
                      value: all ? true : (tristate ? null : false),
                      onChanged: enabled ? (_) => onToggleGroup(group) : null,
                      activeColor: AppColors.primary,
                    ),
                  ),
                  Expanded(child: Text(group.title, style: t.titleSmall)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? AppColors.accentSoft
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count/${group.screens.length}',
                      style: t.labelSmall?.copyWith(
                        color: count > 0
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final screen in group.screens)
                  FilterChip(
                    label: Text(screen),
                    selected: selected.contains(screen),
                    onSelected: enabled ? (_) => onToggle(screen) : null,
                    showCheckmark: true,
                    checkmarkColor: AppColors.accent,
                    selectedColor: AppColors.accentSoft,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: selected.contains(screen)
                          ? AppColors.accent
                          : AppColors.borderStrong,
                    ),
                    labelStyle: t.bodyMedium?.copyWith(
                      color: selected.contains(screen)
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected.contains(screen)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle helpers shared by every screen that edits a permission set.
Set<String> toggleScreen(Set<String> current, String screen) {
  final next = {...current};
  if (!next.remove(screen)) next.add(screen);
  return next;
}

Set<String> toggleGroup(Set<String> current, ScreenGroup group) {
  final all = group.screens.every(current.contains);
  final next = {...current};
  if (all) {
    next.removeAll(group.screens);
  } else {
    next.addAll(group.screens);
  }
  return next;
}
