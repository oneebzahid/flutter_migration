import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/table_export.dart';
import '../../../../../core/widgets/app_data_table.dart';
import '../../../../../core/widgets/export_menu.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../../../../core/widgets/row_action_menu.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../../../../core/widgets/table_toolbar.dart';
import '../../domain/entities/product.dart';
import '../../domain/rules/payable_rules.dart';
import '../controllers/inventory_payables_controller.dart';
import '../widgets/payment_history_dialog.dart';
import '../widgets/record_payment_dialog.dart';

/// Inventory Payables: supplier-credit stock and the amounts still owed.
///
/// The React page exists but is not wired into its router; here it is a real
/// route (`/inventory/payables`) with its own permission, "Inventory Payables".
/// Differences from React (approved rules): overpayment is refused and every
/// payment is kept as a record (see "Payment history").
class InventoryPayablesPage extends StatefulWidget {
  const InventoryPayablesPage({super.key});

  @override
  State<InventoryPayablesPage> createState() => _InventoryPayablesPageState();
}

class _InventoryPayablesPageState extends State<InventoryPayablesPage> {
  final _c = Get.find<InventoryPayablesController>();
  final _currency = Get.find<CurrencyProvider>();
  String _search = '';
  TableSort? _sort;

  ExportTable _export(List<Product> rows, String code, double dueNow) =>
      ExportTable(
        title: 'Inventory Payables',
        subtitle: 'Due Now: ${formatCurrency(dueNow, code)}',
        headers: const [
          'Brand',
          'Model',
          'Stock Status',
          'Supplier Cost',
          'Paid',
          'Remaining',
          'Status',
        ],
        rightAlignedColumns: const {3, 4, 5},
        rows: [
          for (final p in rows)
            [
              p.brandName,
              p.modelName,
              PayableRules.isSoldOut(p)
                  ? 'Sold Out - Due'
                  : '${p.stock} in stock',
              p.supplierCost ?? 0,
              p.supplierPaidAmount ?? 0,
              p.supplierOutstanding,
              (p.supplierPaymentStatus ?? SupplierPaymentStatus.unpaid).label,
            ],
        ],
      );

  List<AppColumn<Product>> _columns(String code) => [
    AppColumn(
      id: 'brand',
      header: 'Brand',
      width: 140,
      sortValue: (p) => p.brandName.toLowerCase(),
      cell: (_, p) => Text(
        p.brandName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    AppColumn(
      id: 'model',
      header: 'Model',
      width: 220,
      sortValue: (p) => p.modelName.toLowerCase(),
      cell: (_, p) => Text(p.modelName, overflow: TextOverflow.ellipsis),
    ),
    AppColumn(
      id: 'stock',
      header: 'Stock Status',
      width: 160,
      sortValue: (p) => p.stock,
      cell: (_, p) => PayableRules.isSoldOut(p)
          ? const StatusBadge(label: 'Sold Out — Due', tone: StatusTone.error)
          : StatusBadge(label: '${p.stock} in stock', tone: StatusTone.info),
    ),
    AppColumn(
      id: 'cost',
      header: 'Supplier Cost',
      width: 170,
      alignRight: true,
      sortValue: (p) => p.supplierCost,
      cell: (_, p) => Text(
        p.supplierCost == null ? '—' : formatCurrency(p.supplierCost!, code),
      ),
    ),
    AppColumn(
      id: 'paid',
      header: 'Paid',
      width: 160,
      alignRight: true,
      sortValue: (p) => p.supplierPaidAmount ?? 0,
      cell: (_, p) => Text(
        formatCurrency(p.supplierPaidAmount ?? 0, code),
        style: const TextStyle(color: AppColors.success),
      ),
    ),
    AppColumn(
      id: 'remaining',
      header: 'Remaining',
      width: 170,
      alignRight: true,
      sortValue: (p) => p.supplierOutstanding,
      cell: (_, p) => Text(
        formatCurrency(p.supplierOutstanding, code),
        style: const TextStyle(
          color: AppColors.warning,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    AppColumn(
      id: 'status',
      header: 'Status',
      width: 130,
      sortValue: (p) =>
          (p.supplierPaymentStatus ?? SupplierPaymentStatus.unpaid).label,
      cell: (_, p) {
        final s = p.supplierPaymentStatus ?? SupplierPaymentStatus.unpaid;
        return StatusBadge(
          label: s.label,
          tone: s == SupplierPaymentStatus.partial
              ? StatusTone.warning
              : StatusTone.error,
        );
      },
    ),
  ];

  List<RowMenuItem> _items(Product p) => [
    RowMenuItem(
      label: 'Record payment',
      icon: Icons.payments_outlined,
      onSelected: () => showRecordPaymentDialog(context, p),
    ),
    RowMenuItem(
      label: 'Payment history',
      icon: Icons.history,
      onSelected: () => showPaymentHistoryDialog(context, p),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      child: Obx(() {
        final list = _c.payables.value;
        final code = _currency.currencyCode.value;
        final totals = _c.totals;
        final rows = TableSort.apply(
          [
            for (final p in list.items)
              if (PayableRules.matches(p, _search)) p,
          ],
          _columns(code),
          _sort,
        );
        final t = Theme.of(context).textTheme;

        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            ScreenHeader(
              title: 'Inventory Payables',
              subtitle: 'Supplier-credit stock that has sold out — amounts still owed',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.warning,
              onBack: () => Get.offNamed(AppRoutes.inventory),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DUE NOW (SOLD OUT)',
                      style: t.labelSmall?.copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      formatCurrency(totals.dueNow, code),
                      style: t.titleMedium?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (totals.stillInStock > 0)
                      Text(
                        '+ ${formatCurrency(totals.stillInStock, code)} still in stock',
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TableToolbar(
              searchHint: 'Search brand, model…',
              onSearch: (v) => setState(() => _search = v),
              onRefresh: _c.load,
              export: ExportSpec(
                fileBaseName: 'inventory-payables',
                rowCount: rows.length,
                build: () => _export(rows, code, totals.dueNow),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppDataTable<Product>(
              columns: _columns(code),
              rows: rows,
              rowKey: (p) => p.id,
              sort: _sort,
              onSort: (id) => setState(() => _sort = TableSort.next(_sort, id)),
              loading: list.isInitialLoading,
              loadingMessage: 'Loading…',
              errorMessage: list.status == LoadStatus.failed
                  ? list.error
                  : null,
              onRetry: _c.load,
              emptyTitle:
                  'No supplier-credit inventory with an outstanding balance.',
              rowActions: (context, p) => RowActionMenu(items: _items(p)),
              actionsWidth: 64,
              cardBuilder: (context, p) => Card(
                child: ListTile(
                  title: Text('${p.brandName} ${p.modelName}'),
                  subtitle: Text(
                    'Remaining ${formatCurrency(p.supplierOutstanding, code)} · '
                    '${PayableRules.isSoldOut(p) ? 'Sold out' : '${p.stock} in stock'}',
                  ),
                  trailing: RowActionMenu(items: _items(p)),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
