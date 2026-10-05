import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/widgets/currency_picker.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_data_table.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_pagination_bar.dart';
import '../../../../../core/widgets/table_toolbar.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/utils/table_export.dart';
import '../../../../../core/widgets/column_visibility_menu.dart';
import '../../../../../core/widgets/export_menu.dart';
import '../../../../../core/widgets/multi_select_field.dart';
import '../../../../../core/widgets/row_action_menu.dart';
import '../../../../../core/widgets/stat_card.dart';
import '../../domain/rules/inventory_filters.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/entities/product.dart';
import '../../domain/rules/report_filters.dart' show distinctSorted;
import '../controllers/inventory_list_controller.dart';
import '../widgets/inventory_badges.dart';
import '../widgets/product_details_dialog.dart';
import '../../../../../core/theme/app_typography.dart';

/// Inventory list (React `/inventory/view`, `/inventory/receivable`): per-product
/// table with KPI cards, local filters, selection and bulk delete.
///
/// Not migrated yet: Report tab, Excel export. The `Move to stock` action only
/// appears in on-order mode (React never passes that mode from its routes).
class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key, this.type = InventoryType.inStock});

  final InventoryType type;

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  bool _showFilters = false;
  String _search = '';
  Set<String> _brands = {};
  Set<String> _models = {};
  Set<String> _categories = {};
  Set<String> _statuses = {};
  Set<String> _locations = {};
  Set<String> _selected = {};
  Set<String> _hidden = {};
  PageState _page = const PageState();
  final _c = Get.find<InventoryListController>();

  @override
  void initState() {
    super.initState();
    _c.load(widget.type);
  }

  static const _statusOptions = [
    ProductStatus.newItem,
    ProductStatus.available,
    ProductStatus.inTransit,
    ProductStatus.damaged,
    ProductStatus.returned,
    ProductStatus.onOrder,
  ];

  int get _activeFilterCount => [
    _locations.isNotEmpty,
    _categories.isNotEmpty,
    _statuses.isNotEmpty,
    _brands.isNotEmpty,
    _models.isNotEmpty,
  ].where((b) => b).length;

  bool get _onOrder => widget.type == InventoryType.onOrder;

  void _reset() => setState(() {
    _brands = {};
    _models = {};
    _categories = {};
    _statuses = {};
    _locations = {};
    _search = '';
    _page = _page.copyWith(page: 1);
  });

  void _filtersChanged(VoidCallback f) => setState(() {
    f();
    _page = _page.copyWith(page: 1);
  });

  bool _matches(Product p) {
    if (_search.isNotEmpty) {
      final hay = [
        p.brandName,
        p.modelName,
        p.category,
        p.status.label,
        p.location,
        p.ownershipType?.label,
        p.supplierPaymentStatus?.label,
        ...p.serialNumbers,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ').toLowerCase();
      if (!hay.contains(_search.toLowerCase())) return false;
    }
    return (_locations.isEmpty || _locations.contains(p.location ?? 'â€”')) &&
        (_categories.isEmpty || _categories.contains(p.category)) &&
        (_statuses.isEmpty || _statuses.contains(p.status.label)) &&
        (_brands.isEmpty || _brands.contains(p.brandName)) &&
        (_models.isEmpty || _models.contains(p.modelName));
  }

  void _onNotice(Notice n) {
    if (n.tag == 'delete' || n.tag == 'receive') {
      setState(
        () => _selected = {..._selected}
          ..removeWhere(
            (id) => !_c.listFor(widget.type).items.any((p) => p.id == id),
          ),
      );
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete inventory item',
      message:
          'You are about to delete:\n${p.brandName} ${p.modelName}\n'
          '${p.category} Â· ${p.stock} units in stock\n\n'
          'This item will be moved to Deleted Inventory and hidden from all live '
          'views. The original record is preserved under Deleted Inventory.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && mounted) {
      _c.deleteProduct(p.id);
    }
  }

  Future<void> _deleteSelected(List<Product> selected) async {
    final ok = await showConfirmDialog(
      context,
      title:
          'Delete ${selected.length} item${selected.length == 1 ? '' : 's'}?',
      message:
          'You\'re about to delete ${selected.length} product(s):\n'
          '${selected.take(8).map((p) => 'â€¢ ${p.brandName} ${p.modelName} (${p.stock} in stock)').join('\n')}'
          '${selected.length > 8 ? '\nâ€¦and ${selected.length - 8} more' : ''}\n\n'
          'All selected items will be moved to Deleted Inventory.',
      confirmLabel: 'Delete ${selected.length}',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _selected = {});
    // Sequential: the controller ignores a call while another is in flight.
    for (final p in selected) {
      await _c.deleteProduct(p.id);
    }
  }

  Future<void> _view(Product p, String code) async {
    final action = await showProductDetailsDialog(
      context,
      product: p,
      currencyCode: code,
      canReceive: _onOrder,
    );
    if (!mounted) return;
    switch (action) {
      case ProductDialogAction.delete:
        await _delete(p);
      case ProductDialogAction.receive:
        _c.receiveProduct(p.id);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      onNotice: _onNotice,
      child: Obx(() {
        final list = _c.listFor(widget.type);
        final code = Get.find<CurrencyProvider>().currencyCode.value;
        final busy = _c.busy.value;
        final all = list.items;
        final loading = list.isInitialLoading;
        final display = all.where(_matches).toList();
        final stats = ProductStats.of(
          all,
        ); // React: not affected by local filters
        final selectedProducts = [
          for (final p in display)
            if (_selected.contains(p.id)) p,
        ];
        final summary = selectedProducts.isNotEmpty
            ? selectedProducts
            : display;
        final allSelected =
            display.isNotEmpty &&
            display.every((p) => _selected.contains(p.id));
        final pageRows = _page.slice(display);

        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            _header(context, stats, code),
            const SizedBox(height: AppSpacing.lg),
            _kpis(stats, code),
            const SizedBox(height: AppSpacing.lg),
            TableToolbar(
              searchHint: 'Search brand, model, category, status, locationâ€¦',
              onSearch: (v) => _filtersChanged(() => _search = v),
              filterCount: _activeFilterCount,
              filtersOpen: _showFilters,
              onOpenFilters: () => setState(() => _showFilters = !_showFilters),
              export: ExportSpec(
                fileBaseName: 'inventory-list',
                rowCount: display.length,
                build: () => _exportTable(display, code),
              ),
              trailing: [
                ColumnVisibilityMenu(
                  columns: const {
                    'stockAuto': 'Stock-In Date (Auto)',
                    'stockManual': 'Stock-In Date (Manual)',
                    'type': 'Type',
                    'brand': 'Brand',
                    'model': 'Model',
                    'serial': 'Serial No.',
                    'location': 'Location',
                    'ownership': 'Ownership',
                    'stock': 'Stock',
                    'sell': 'Sell Price',
                    'payment': 'Sold Goods Payment',
                    'condition': 'Condition',
                    'current': 'Current Status',
                  },
                  hidden: _hidden,
                  onChanged: (h) => setState(() => _hidden = h),
                ),
              ],
            ),
            if (_showFilters) ...[
              const SizedBox(height: AppSpacing.lg),
              _filterPanel(all),
            ],
            const SizedBox(height: AppSpacing.lg),
            _countLine(
              context,
              display.length,
              all.length,
              selectedProducts,
              busy,
              loading,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppDataTable<Product>(
              columns: _columns(code),
              rows: pageRows,
              rowKey: (p) => p.id,
              loading: loading,
              loadingMessage: 'Loading inventoryâ€¦',
              errorMessage: list.status == LoadStatus.failed
                  ? list.error
                  : null,
              onRetry: () => _c.load(widget.type),
              emptyTitle: 'No products found',
              selectedKeys: _selected,
              allSelected: allSelected,
              someSelected: _selected.isNotEmpty && !allSelected,
              onToggleRow: (p) => setState(() {
                _selected = {..._selected};
                if (!_selected.remove(p.id)) _selected.add(p.id);
              }),
              onToggleAll: (select) => setState(
                () => _selected = select ? {for (final p in display) p.id} : {},
              ),
              rowColor: (p, i) => p.status == ProductStatus.inTransit
                  ? AppColors.warningSoft.withValues(alpha: 0.6)
                  : null,
              rowActions: (context, p) => RowActionMenu(
                items: [
                  RowMenuItem(
                    label: 'View details',
                    icon: Icons.visibility_outlined,
                    onSelected: () => _view(p, code),
                  ),
                  if (_onOrder)
                    RowMenuItem(
                      label: 'Move to stock',
                      icon: Icons.move_to_inbox_outlined,
                      enabled: !busy,
                      onSelected: () => _c.receiveProduct(p.id),
                    ),
                  RowMenuItem(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    danger: true,
                    enabled: !busy,
                    onSelected: () => _delete(p),
                  ),
                ],
              ),
              actionsWidth: 64,
              cardBuilder: (context, p) => _card(context, p, code, busy),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPaginationBar(
              state: _page,
              total: display.length,
              onChanged: (p) => setState(() => _page = p),
            ),
            if (!loading && display.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _summaryBar(context, summary, selectedProducts.isNotEmpty, code),
            ],
          ],
        );
      }),
    );
  }

  /// React exports every filtered product with 10 columns (sell price as a
  /// plain number).
  ExportTable _exportTable(List<Product> rows, String code) => ExportTable(
    title: 'Inventory List',
    subtitle: '${rows.length} products',
    headers: [
      'Brand',
      'Model',
      'Type',
      'Serial No.',
      'Location',
      'Ownership',
      'Stock',
      'Sell ($code)',
      'Condition',
      'Current Status',
    ],
    rightAlignedColumns: const {6, 7},
    rows: [
      for (final p in rows)
        [
          p.brandName,
          p.modelName,
          p.category,
          p.serialNumbers.join(', '),
          p.location ?? '',
          p.ownershipType?.label ?? 'â€”',
          p.stock,
          p.sellPrice,
          p.status.label,
          p.stock > 0 ? StockState.inStock.label : StockState.sold.label,
        ],
    ],
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€ header / KPIs / filters â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _header(BuildContext context, ProductStats stats, String code) {
    return ScreenHeader(
      title: 'Inventory',
      subtitle:
          '${stats.totalProducts} products Â· ${formatCount(stats.totalStock)} units Â· '
          '${formatCurrency(stats.totalValue, code)} value',
      icon: Icons.view_list_outlined,
      iconColor: AppColors.sidebar,
      onBack: () => Get.offNamed(AppRoutes.inventory),
      actions: [
        const CurrencyPicker(),
        AppButton(
          label: 'Add stock',
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          onPressed: () => Get.offNamed(AppRoutes.inventoryAddExisting),
        ),
        AppButton(
          label: 'New product',
          icon: Icons.add,
          onPressed: () => Get.offNamed(AppRoutes.inventoryCreate),
        ),
      ],
    );
  }

  Widget _kpis(ProductStats s, String code) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: [
      StatCard(label: 'Products', value: formatCount(s.totalProducts)),
      StatCard(
        label: 'Stock',
        value: formatCount(s.totalStock),
        color: AppColors.success,
      ),
      StatCard(
        label: 'In Transit',
        value: formatCount(s.inTransit),
        color: AppColors.warning,
      ),
      StatCard(
        label: 'Available',
        value: formatCount(s.available),
        color: AppColors.textSecondary,
      ),
      // Cost-based, as in React (the table shows sell price).
      StatCard(
        label: 'Total Value',
        value: formatCurrency(s.totalValue, code),
        width: 220,
      ),
    ],
  );

  Widget _filterPanel(List<Product> all) {
    final brands = distinctSorted(all.map((p) => p.brandName));
    final models = distinctSorted(
      all
          .where((p) => _brands.isEmpty || _brands.contains(p.brandName))
          .map((p) => p.modelName),
    );
    final categories = uniqueCategories(all);
    final locations = uniqueLocations(all);

    Widget field(Widget w) => SizedBox(width: 200, child: w);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            field(
              MultiSelectField(
                label: 'Brand',
                allLabel: 'All Brands',
                options: brands,
                selected: _brands,
                onChanged: (v) => _filtersChanged(() {
                  _brands = v;
                  // Models outside the new brand selection are pruned.
                  _models = _models.intersection(
                    distinctSorted(
                      all
                          .where((p) => v.isEmpty || v.contains(p.brandName))
                          .map((p) => p.modelName),
                    ).toSet(),
                  );
                }),
              ),
            ),
            field(
              MultiSelectField(
                label: 'Model',
                allLabel: 'All Models',
                options: models,
                selected: _models,
                onChanged: (v) => _filtersChanged(() => _models = v),
              ),
            ),
            field(
              MultiSelectField(
                label: 'Category',
                allLabel: 'All Categories',
                options: categories,
                selected: _categories,
                onChanged: (v) => _filtersChanged(() => _categories = v),
              ),
            ),
            field(
              MultiSelectField(
                label: 'Status',
                allLabel: 'All Statuses',
                options: [for (final s in _statusOptions) s.label],
                selected: _statuses,
                onChanged: (v) => _filtersChanged(() => _statuses = v),
              ),
            ),
            field(
              MultiSelectField(
                label: 'Location',
                allLabel: 'All Locations',
                options: locations,
                selected: _locations,
                onChanged: (v) => _filtersChanged(() => _locations = v),
              ),
            ),
            AppButton(
              label: 'Clear filters',
              variant: AppButtonVariant.secondary,
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _countLine(
    BuildContext context,
    int shown,
    int total,
    List<Product> selected,
    bool busy,
    bool loading,
  ) {
    if (loading) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Showing $shown of $total products',
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        if (selected.isNotEmpty) ...[
          Text('${selected.length} selected', style: t.labelLarge),
          TextButton(
            onPressed: () => setState(() => _selected = {}),
            child: const Text('Clear selection'),
          ),
          AppButton(
            label: 'Delete selected (${selected.length})',
            icon: Icons.delete_outline,
            variant: AppButtonVariant.danger,
            onPressed: busy ? null : () => _deleteSelected(selected),
          ),
        ],
      ],
    );
  }

  Widget _summaryBar(
    BuildContext context,
    List<Product> rows,
    bool isSelection,
    String code,
  ) {
    final t = Theme.of(context).textTheme;
    final units = rows.fold<int>(0, (s, p) => s + p.stock);
    final cost = rows.fold<double>(
      0,
      (s, p) => s + (p.costPrice ?? 0) * p.stock,
    );
    final sell = rows.fold<double>(0, (s, p) => s + p.sellPrice * p.stock);

    Widget metric(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        Text(
          value,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Sum of ${rows.length} ${isSelection ? 'selected' : 'filtered'}',
              style: t.labelLarge?.copyWith(
                color: isSelection
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
            metric('Total Units', formatCount(units)),
            metric('Total Cost Value', formatCurrency(cost, code)),
            metric('Total Sell Value', formatCurrency(sell, code)),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€ table â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<AppColumn<Product>> _columns(String code) {
    String serialText(Product p) {
      final s = p.serialNumbers;
      if (s.isEmpty) return 'â€”';
      return s.length <= 2
          ? s.join(', ')
          : '${s.take(2).join(', ')} +${s.length - 2} more';
    }

    final cols = <AppColumn<Product>>[
      AppColumn(
        id: 'stockAuto',
        header: 'Stock-In Date (Auto)',
        width: 150,
        cell: (_, p) => Text(formatDate(p.createdAt)),
      ),
      AppColumn(
        id: 'stockManual',
        header: 'Stock-In Date (Manual)',
        width: 160,
        cell: (_, p) => Text(
          formatDate(p.stockInDateManual),
          style: TextStyle(
            color: p.stockInDateManual == null
                ? AppColors.textDisabled
                : AppColors.textPrimary,
          ),
        ),
      ),
      AppColumn(
        id: 'type',
        header: 'Type',
        width: 160,
        cell: (_, p) => Text(p.category),
      ),
      AppColumn(
        id: 'brand',
        header: 'Brand',
        width: 120,
        cell: (_, p) => Text(
          p.brandName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      AppColumn(
        id: 'model',
        header: 'Model',
        width: 180,
        cell: (_, p) => Text(p.modelName),
      ),
      AppColumn(
        id: 'serial',
        header: 'Serial No.',
        width: 220,
        cell: (_, p) => Tooltip(
          message: p.serialNumbers.join(', '),
          child: Text(
            serialText(p),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.monoFamily,
              fontFamilyFallback: AppTypography.monoFallback,
              fontSize: 12,
            ),
          ),
        ),
      ),
      AppColumn(
        id: 'location',
        header: 'Location',
        width: 170,
        cell: (_, p) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.place_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(p.location ?? 'â€”', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      AppColumn(
        id: 'ownership',
        header: 'Ownership',
        width: 110,
        cell: (_, p) => InventoryBadges.ownership(p.ownershipType),
      ),
      AppColumn(
        id: 'stock',
        header: 'Stock',
        width: 100,
        cell: (_, p) => Text(
          '${p.stock} units',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      AppColumn(
        id: 'sell',
        header: 'Sell ($code)',
        width: 160,
        alignRight: true,
        cell: (_, p) => Text(
          formatCurrency(p.sellPrice, code),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      AppColumn(
        id: 'payment',
        header: 'Sold Goods Payment',
        width: 170,
        // Only credit stock has a supplier payment (React).
        cell: (_, p) => p.ownershipType == OwnershipType.credit
            ? InventoryBadges.payment(
                p.supplierPaymentStatus ?? SupplierPaymentStatus.unpaid,
              )
            : const Text('â€”'),
      ),
      AppColumn(
        id: 'condition',
        header: 'Condition',
        width: 120,
        // React shows the product status here.
        cell: (_, p) => InventoryBadges.productStatus(p.status),
      ),
      AppColumn(
        id: 'current',
        header: 'Current Status',
        width: 130,
        cell: (_, p) => InventoryBadges.stockState(
          p.stock > 0 ? StockState.inStock : StockState.sold,
        ),
      ),
    ];
    return [
      for (final c in cols)
        if (!_hidden.contains(c.id)) c,
    ];
  }

  Widget _card(BuildContext context, Product p, String code, bool busy) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: () => _view(p, code),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _selected.contains(p.id),
                    onChanged: (_) => setState(() {
                      _selected = {..._selected};
                      if (!_selected.remove(p.id)) _selected.add(p.id);
                    }),
                  ),
                  Expanded(
                    child: Text(
                      '${p.brandName} ${p.modelName}',
                      style: t.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete product',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: busy ? null : () => _delete(p),
                  ),
                ],
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  InventoryBadges.productStatus(p.status),
                  InventoryBadges.ownership(p.ownershipType),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${p.category} Â· ${p.location ?? 'â€”'}',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              Text(
                '${p.stock} units Â· Sell ${formatCurrency(p.sellPrice, code)}',
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
