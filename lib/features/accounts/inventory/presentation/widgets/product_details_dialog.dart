import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/product.dart';
import 'inventory_badges.dart';
import '../../../../../core/theme/app_typography.dart';

enum ProductDialogAction { delete, receive }

/// Read-only product details (React "Product Details" modal). Returns the
/// action chosen in the footer, or null when just closed.
///
/// Not migrated yet: payment details panel and the transfer-route pill
/// (they depend on the Payments / Product Transfer modules).
Future<ProductDialogAction?> showProductDetailsDialog(
  BuildContext context, {
  required Product product,
  required String currencyCode,
  required bool canReceive,
}) {
  return showDialog<ProductDialogAction>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      Widget field(String label, Widget value) => SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            value,
          ],
        ),
      );
      Text txt(String s) => Text(s, style: t.titleSmall);

      return AppDialog(
        title: 'Product details',
        maxWidth: 640,
        actions: [
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(ProductDialogAction.delete),
          ),
          if (canReceive)
            AppButton(
              label: 'Move to stock',
              icon: Icons.move_to_inbox_outlined,
              onPressed: () =>
                  Navigator.of(ctx).pop(ProductDialogAction.receive),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.lg,
              children: [
                field('Brand', txt(product.brandName)),
                field('Model', txt(product.modelName)),
                field('Category', txt(product.category)),
                field(
                  'Status',
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InventoryBadges.productStatus(product.status),
                  ),
                ),
                field('Stock', txt('${product.stock} units')),
                field(
                  'Warranty',
                  txt(
                    '${product.warrantyYears} year${product.warrantyYears == 1 ? '' : 's'}',
                  ),
                ),
                field(
                  'Cost price',
                  txt(
                    product.costPrice == null
                        ? '—'
                        : formatCurrency(product.costPrice!, currencyCode),
                  ),
                ),
                field(
                  'Sell price',
                  txt(formatCurrency(product.sellPrice, currencyCode)),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xxl),
            field(
              'Primary location',
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      (product.location ?? '').isEmpty
                          ? '—'
                          : product.location!,
                      style: t.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (product.serialNumbers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Serial numbers (${product.serialNumbers.length}) — by location',
                style: t.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: AppColors.surfaceMuted,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (product.location ?? '').isEmpty
                                  ? 'Unknown'
                                  : product.location!,
                              style: t.labelLarge,
                            ),
                          ),
                          Text(
                            '${product.serialNumbers.length} unit${product.serialNumbers.length == 1 ? '' : 's'}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final s in product.serialNumbers)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontFamily: AppTypography.monoFamily,
                                  fontFamilyFallback:
                                      AppTypography.monoFallback,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (product.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Description',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(product.description, style: t.bodyMedium),
            ],
          ],
        ),
      );
    },
  );
}
