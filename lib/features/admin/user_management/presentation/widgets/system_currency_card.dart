import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/settings/currency_option.dart';

/// System currency picker (React: "System Currency" card). Symbol-only: it
/// relabels amounts app-wide and never converts stored figures.
class SystemCurrencyCard extends StatelessWidget {
  const SystemCurrencyCard({
    super.key,
    required this.code,
    required this.busy,
    required this.onChanged,
  });

  final String code;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final heading = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.payments_outlined, color: AppColors.success),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System currency', style: t.titleSmall),
              Text(
                'Relabels amounts across Income Statement, Balance Sheet and '
                'Receivables & Payables. Symbol only — figures are not converted.',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );

    final picker = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            key: ValueKey(code),
            initialValue: code,
            isExpanded: true,
            onChanged: busy ? null : (v) => v == null ? null : onChanged(v),
            items: [
              for (final c in kCurrencies)
                DropdownMenuItem(
                  value: c.code,
                  child: Text('${c.code} — ${c.label}'),
                ),
            ],
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 820
              ? Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: AppSpacing.lg),
                    picker,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: AppSpacing.md),
                    picker,
                  ],
                ),
        ),
      ),
    );
  }
}
