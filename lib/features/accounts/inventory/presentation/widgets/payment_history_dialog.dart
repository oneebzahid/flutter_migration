import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/supplier_payment.dart';
import '../controllers/inventory_payables_controller.dart';

Future<void> showPaymentHistoryDialog(BuildContext context, Product product) =>
    showDialog<void>(
      context: context,
      builder: (_) => _PaymentHistoryDialog(product: product),
    );

/// Every payment recorded for one product, newest first (React kept only the
/// paid total; the records are what an audit trail needs).
class _PaymentHistoryDialog extends StatelessWidget {
  const _PaymentHistoryDialog({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<InventoryPayablesController>();
    final code = Get.find<CurrencyProvider>().currencyCode.value;
    final t = Theme.of(context).textTheme;
    return AppDialog(
      title: 'Payments — ${product.brandName} ${product.modelName}',
      maxWidth: 480,
      child: FutureBuilder<List<SupplierPayment>>(
        future: c.history(product.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return Text(
              'No payments recorded yet.',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            );
          }
          return Column(
            children: [
              for (final p in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatCurrency(p.amount, code)),
                  subtitle: Text(
                    '${formatDate(p.date)} · ${p.channel.label}'
                    '${p.bankName == null ? '' : ' (${p.bankName})'}\n${p.reference}',
                  ),
                  isThreeLine: true,
                ),
            ],
          );
        },
      ),
    );
  }
}
