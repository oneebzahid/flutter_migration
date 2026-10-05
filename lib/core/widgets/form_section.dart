import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The raised white panel every form is built from: border + soft shadow so
/// form sections stand out from the page background.
class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.highlight,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Clip clipBehavior;

  /// Optional accent border (e.g. a section with errors).
  final Color? highlight;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: clipBehavior,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: highlight ?? AppColors.border),
      boxShadow: AppShadows.card,
    ),
    padding: padding,
    child: child,
  );
}

/// A titled form block: heading (+ optional step badge, subtitle, trailing
/// action) above its fields. Use this for every new form so spacing, shadow
/// and typography stay identical across screens.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.step,
    this.trailing,
    this.highlight,
  });

  final String title;
  final String? subtitle;

  /// Shows a numbered badge before the title (e.g. product row 1).
  final int? step;
  final Widget? trailing;
  final Color? highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FormCard(
      highlight: highlight,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (step != null) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
