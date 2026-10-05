import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/inventory_report_row.dart';
import 'inventory_badges.dart';

/// Read-only view of one serial row (the dashboard's "View details").
Future<void> showSerialDetailsDialog(
  BuildContext context, {
  required InventoryReportRow row,
  required String currencyCode,
}) {
  String money(double? v) => v == null ? '—' : formatCurrency(v, currencyCode);
  String text(String? s) => (s == null || s.isEmpty) ? '—' : s;
  final sold = row.currentStatus == StockState.sold;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      Widget field(String label, Widget value) => SizedBox(
        width: 250,
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
      Widget v(String s) => Text(s, style: t.titleSmall);
      Widget badge(Widget w) =>
          Align(alignment: Alignment.centerLeft, child: w);

      return AppDialog(
        title: '${row.brandName} ${row.modelName}',
        maxWidth: 640,
        actions: [
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        child: Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.lg,
          children: [
            field('Serial No.', v(text(row.serialNumber))),
            field('Type', v(text(row.type))),
            field('Location', v(text(row.location))),
            field('Ownership', badge(InventoryBadges.ownership(row.ownership))),
            field('Condition', badge(InventoryBadges.condition(row.condition))),
            field(
              'Status',
              badge(InventoryBadges.stockState(row.currentStatus)),
            ),
            field('Stock-in (auto)', v(formatDate(row.stockInDateAuto))),
            field('Stock-in (manual)', v(formatDate(row.stockInDateManual))),
            field('Sold date', v(sold ? formatDate(row.soldDate) : '—')),
            field('Invoice #', v(sold ? text(row.invoiceNumber) : '—')),
            field('Supplier cost', v(money(row.supplierCost))),
            field('Purchasing cost', v(money(row.purchasingCost))),
            field(
              'Sold goods payment',
              badge(InventoryBadges.payment(row.supplierPaymentStatus)),
            ),
            field('Paid amount', v(money(row.supplierPaidAmount))),
          ],
        ),
      );
    },
  );
}
