import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum StatusTone { success, warning, error, info, neutral }

/// Compact pill for statuses (Paid, Pending, Overdue, ...). Use [tone] for
/// semantic colours, or [background]/[foreground] for a specific palette.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.background,
    this.foreground,
  });

  final String label;
  final StatusTone tone;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final (toneBg, toneFg) = switch (tone) {
      StatusTone.success => (AppColors.successSoft, AppColors.success),
      StatusTone.warning => (AppColors.warningSoft, AppColors.warning),
      StatusTone.error => (AppColors.errorSoft, AppColors.error),
      StatusTone.info => (AppColors.infoSoft, AppColors.info),
      StatusTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
    };
    final bg = background ?? toneBg;
    final fg = foreground ?? toneFg;
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
        ),
      ),
    );
  }
}
