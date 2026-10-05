import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/table_export.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_data_table.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/table_toolbar.dart';
import '../../../../../core/widgets/export_menu.dart';
import '../../../../../core/widgets/row_action_menu.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../domain/entities/inventory_records.dart';
import '../controllers/deleted_inventory_controller.dart';
import '../../../../../core/theme/app_typography.dart';

final DateFormat _stamp = DateFormat('d MMM y, hh:mm a', 'en_US');
String _when(DateTime d) => _stamp.format(d);

/// Deleted Inventory (React `/inventory/deleted`): read-only archive of
/// removed products and serials. React has no restore button (the service
/// function exists but nothing calls it), so none is offered here either.
class DeletedInventoryPage extends StatefulWidget {
  const DeletedInventoryPage({super.key});

  @override
  State<DeletedInventoryPage> createState() => _DeletedInventoryPageState();
}

class _DeletedInventoryPageState extends State<DeletedInventoryPage> {
  String _search = '';
  final _c = Get.find<DeletedInventoryController>();

  /// Brand, model, category, deleter email and deleter name (React).
  List<DeletedProduct> _filter(List<DeletedProduct> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) {
      final p = r.product;
      return p.brandName.toLowerCase().contains(q) ||
          p.modelName.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          r.deletedBy.email.toLowerCase().contains(q) ||
          r.deletedBy.name.toLowerCase().contains(q);
    }).toList();
  }

  ExportTable _export(List<DeletedProduct> rows) => ExportTable(
    title: 'Deleted Inventory',
    subtitle: '${rows.length} record(s)',
    headers: const [
      'Product',
      'Original ID',
      'Category',
      'Location',
      'Stock',
      'Deleted By',
      'Account',
      'Deleted At',
    ],
    rightAlignedColumns: const {4},
    rows: [
      for (final r in rows)
        [
          '${r.product.brandName} ${r.product.modelName}',
          r.originalId,
          r.product.category,
          r.displayLocation,
          r.product.stock,
          r.deletedBy.name,
          r.deletedBy.email,
          _when(r.deletedAt),
        ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = _c.deleted.value;
      final code = Get.find<CurrencyProvider>().currencyCode.value;
      final loading = list.isInitialLoading;
      final rows = _filter(list.items);
      final t = Theme.of(context).textTheme;
      final q = _search.trim();

      return ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ScreenHeader(
            title: 'Deleted Inventory',
            subtitle: 'Archived records of removed inventory items — read-only',
            icon: Icons.delete_outline,
            iconColor: AppColors.error,
            onBack: () => Get.offNamed(AppRoutes.inventory),
          ),
          const SizedBox(height: AppSpacing.lg),
          TableToolbar(
            searchHint: 'Search brand, model, deleted by…',
            onSearch: (v) => setState(() => _search = v),
            onRefresh: () => _c.load(),
            export: ExportSpec(
              fileBaseName: 'deleted-inventory',
              rowCount: rows.length,
              build: () => _export(rows),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppDataTable<DeletedProduct>(
            rows: rows,
            rowKey: (r) => r.archiveId,
            loading: loading,
            loadingMessage: 'Loading deleted records…',
            errorMessage: list.status == LoadStatus.failed ? list.error : null,
            onRetry: () => _c.load(),
            emptyTitle: q.isEmpty
                ? 'No deleted inventory yet'
                : 'No matching records',
            columns: [
              AppColumn(
                id: 'product',
                header: 'Product',
                width: 260,
                cell: (_, r) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.product.brandName} ${r.product.modelName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      r.originalId,
                      style: const TextStyle(
                        fontFamily: AppTypography.monoFamily,
                        fontFamilyFallback: AppTypography.monoFallback,
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              AppColumn(
                id: 'category',
                header: 'Category',
                width: 160,
                cell: (_, r) => Text(r.product.category),
              ),
              AppColumn(
                id: 'location',
                header: 'Location',
                width: 180,
                cell: (_, r) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        r.displayLocation,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              AppColumn(
                id: 'stock',
                header: 'Stock',
                width: 110,
                // Always plural, as React ("1 units").
                cell: (_, r) => Text('${r.product.stock} units'),
              ),
              AppColumn(
                id: 'by',
                header: 'Deleted By',
                width: 240,
                cell: (_, r) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.deletedBy.name,
                      style: t.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      r.deletedBy.email,
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textDisabled,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppColumn(
                id: 'at',
                header: 'Deleted At',
                width: 200,
                cell: (_, r) => Text(
                  _when(r.deletedAt),
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
            rowActions: (context, r) => RowActionMenu(
              items: [
                RowMenuItem(
                  label: 'View details',
                  icon: Icons.visibility_outlined,
                  onSelected: () => _showDetails(context, r, code),
                ),
              ],
            ),
            actionsWidth: 64,
            cardBuilder: (context, r) => Card(
              child: ListTile(
                title: Text('${r.product.brandName} ${r.product.modelName}'),
                subtitle: Text(
                  '${r.product.category} · ${r.product.stock} units · ${r.displayLocation}\n'
                  '${r.deletedBy.name} · ${_when(r.deletedAt)}',
                ),
                isThreeLine: true,
                onTap: () => _showDetails(context, r, code),
              ),
            ),
          ),
          if (!loading && list.status != LoadStatus.failed && rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${rows.length} deleted record${rows.length == 1 ? '' : 's'}'
                  '${q.isEmpty ? '' : ' matching "$q"'}',
                  style: t.bodySmall?.copyWith(color: AppColors.textDisabled),
                ),
              ),
            ),
        ],
      );
    });
  }

  void _showDetails(BuildContext context, DeletedProduct r, String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final p = r.product;
        Widget cell(String label, String value, {bool mono = false}) =>
            SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? '—' : value,
                    style: mono
                        ? const TextStyle(
                            fontFamily: AppTypography.monoFamily,
                            fontFamilyFallback: AppTypography.monoFallback,
                            fontSize: 13,
                          )
                        : t.titleSmall,
                  ),
                ],
              ),
            );
        Widget section(String title) => Padding(
          padding: const EdgeInsets.only(
            bottom: AppSpacing.sm,
            top: AppSpacing.lg,
          ),
          child: Text(
            title.toUpperCase(),
            style: t.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        );

        return AppDialog(
          title: 'Deleted inventory record',
          maxWidth: 640,
          actions: [
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.md,
                  children: [
                    cell('Deleted by', r.deletedBy.name),
                    cell('Account', r.deletedBy.email, mono: true),
                    cell('Deleted at', _when(r.deletedAt)),
                    cell('Original ID', r.originalId, mono: true),
                  ],
                ),
              ),
              section('Product details'),
              Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.md,
                children: [
                  cell('Brand', p.brandName),
                  cell('Model', p.modelName),
                  cell('Category', p.category),
                  cell('Status', p.status.label),
                  cell('Stock', '${p.stock} units'),
                  cell('Location', r.displayLocation),
                  cell(
                    'Cost price',
                    p.costPrice == null
                        ? ''
                        : formatCurrency(p.costPrice!, code),
                  ),
                  cell('Sell price', formatCurrency(p.sellPrice, code)),
                  cell(
                    'Warranty',
                    '${p.warrantyYears} yr${p.warrantyYears == 1 ? '' : 's'}',
                  ),
                  cell('Buy type', p.buyType.label),
                ],
              ),
              if (p.serialNumbers.isNotEmpty) ...[
                section('Serial numbers (${p.serialNumbers.length})'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in p.serialNumbers)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontFamily: AppTypography.monoFamily,
                            fontFamilyFallback: AppTypography.monoFallback,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (p.description.isNotEmpty) ...[
                section('Description'),
                Text(
                  p.description,
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
