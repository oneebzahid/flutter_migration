import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/table_export.dart';
import '../../../../../core/widgets/active_filter_chips.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_data_table.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_pagination_bar.dart';
import '../../../../../core/widgets/column_visibility_menu.dart';
import '../../../../../core/widgets/export_menu.dart';
import '../../../../../core/widgets/filter_sheet.dart';
import '../../../../../core/widgets/multi_select_field.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../../../../core/widgets/row_action_menu.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/widgets/table_toolbar.dart';
import '../../../../auth/domain/entities/auth_user.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/rules/report_filters.dart';
import '../controllers/inventory_dashboard_controller.dart';
import '../widgets/inventory_badges.dart';
import '../widgets/serial_details_dialog.dart';

/// Inventory dashboard (React `/inventory`): per-serial table with filters,
/// sorting, selection, bulk delete, totals and Excel/PDF download.
///
/// With [reportMode] it is the standalone Inventory Report
/// (React `/inventory/report`): the same table without quick actions, totals
/// footer or pagination (React shows every filtered row on one scroll).
///
/// Not migrated yet: the invoice PDF preview (needs the Invoices module).
class InventoryDashboardPage extends StatefulWidget {
  const InventoryDashboardPage({super.key, this.reportMode = false});

  final bool reportMode;

  @override
  State<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends State<InventoryDashboardPage> {
  ReportFilters _filters = ReportFilters.empty;
  Set<String> _selected = {};
  Set<String> _hidden = {};
  late PageState _page = PageState.restore(_storageKey);
  TableSort? _sort;
  bool _showFilters = false;

  String get _storageKey =>
      widget.reportMode ? 'inventory.report' : 'inventory.dashboard';

  static const _columnHeaders = {
    'stockAuto': 'Stock-In Date (Auto)',
    'stockManual': 'Stock-In Date (Manual)',
    'type': 'Type',
    'brand': 'Brand',
    'model': 'Model',
    'serial': 'Serial No.',
    'location': 'Location',
    'ownership': 'Ownership',
    'condition': 'Condition',
    'status': 'Status',
    'soldDate': 'Sold Date',
    'invoice': 'Invoice #',
    'supplierCost': 'Supplier Cost',
    'purchasingCost': 'Purchasing Cost',
    'payment': 'Sold Goods Payment',
  };

  void _setFilters(ReportFilters f) => setState(() {
    _filters = f;
    _page = _page.copyWith(page: 1);
  });

  final _c = Get.find<InventoryDashboardController>();

  void _refresh() => _c.loadReport();

  void _onNotice(Notice n) {
    if (n.tag == 'delete-serials') setState(() => _selected = {});
  }

  SerialRef _ref(InventoryReportRow r) => SerialRef(
    productId: r.productId,
    serial: r.serialNumber,
    brand: r.brandName,
    model: r.modelName,
  );

  Future<void> _deleteOne(InventoryReportRow r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this item?',
      message:
          '${r.brandName} — ${r.modelName}\n'
          'Serial: ${r.serialNumber.isEmpty ? '—' : r.serialNumber}\n'
          'Location: ${r.location.isEmpty ? '—' : r.location}\n\n'
          'Moves to Deleted Inventory — recoverable. Only this serial is removed '
          'from stock; sibling serials of the same product stay untouched.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && mounted) {
      _c.deleteSerials([_ref(r)]);
    }
  }

  Future<void> _deleteSelected(List<InventoryReportRow> selectedRows) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete selected items?',
      message:
          'You\'ve selected ${selectedRows.length} serial(s) to delete. Each '
          'will be individually removed from stock — sibling serials of the '
          'same product are not affected.\n\n'
          'Items move to Deleted Inventory — recoverable.',
      confirmLabel: 'Delete ${selectedRows.length}',
      destructive: true,
    );
    if (ok && mounted) {
      _c.deleteSerials([for (final r in selectedRows) _ref(r)]);
    }
  }

  bool get _compact => MediaQuery.sizeOf(context).width < 720;

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      onNotice: _onNotice,
      child: Obx(() {
        final report = _c.report.value;
        final user = Get.find<SessionProvider>().currentUser;
        final code = Get.find<CurrencyProvider>().currencyCode.value;
        final busy = _c.busy.value;
        final all = report.items;
        final loading = report.isInitialLoading;
        final columns = _columns(code);
        final displayed = TableSort.apply(_filters.apply(all), columns, _sort);

        final selectedRows = [
          for (final r in displayed)
            if (_selected.contains(r.key)) r,
        ];
        final totalsSource = selectedRows.isNotEmpty ? selectedRows : displayed;
        final pageRows = widget.reportMode ? displayed : _page.slice(displayed);
        final allSelected =
            displayed.isNotEmpty &&
            displayed.every((r) => _selected.contains(r.key));

        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            _header(context),
            const SizedBox(height: AppSpacing.lg),
            if (!widget.reportMode) ...[
              _quickActions(context, user),
              const SizedBox(height: AppSpacing.lg),
            ],
            TableToolbar(
              searchHint: widget.reportMode
                  ? 'Search brand, model, serial, location, invoice…'
                  : 'Search brand, model, serial, invoice…',
              onSearch: (v) => _setFilters(_filters.copyWith(search: v)),
              filterCount: _filters.activeCount,
              filtersOpen: _showFilters,
              onOpenFilters: () => _openFilters(context, all),
              onRefresh: _refresh,
              export: ExportSpec(
                fileBaseName: widget.reportMode
                    ? 'inventory-report'
                    : 'inventory',
                rowCount: displayed.length,
                build: () => _exportTable(displayed, code),
              ),
              trailing: [
                ColumnVisibilityMenu(
                  columns: _columnHeaders,
                  hidden: _hidden,
                  onChanged: (h) => setState(() => _hidden = h),
                ),
              ],
            ),
            if (_showFilters && !_compact) ...[
              const SizedBox(height: AppSpacing.md),
              _filterPanel(context, all),
            ],
            if (_filters.activeCount > 0) ...[
              const SizedBox(height: AppSpacing.md),
              ActiveFilterChips(
                filters: _activeFilters(),
                onClearAll: () => _setFilters(ReportFilters.empty),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _tableHeader(context, displayed, selectedRows, busy, loading),
            const SizedBox(height: AppSpacing.sm),
            AppDataTable<InventoryReportRow>(
              columns: [
                for (final c in columns)
                  if (!_hidden.contains(c.id)) c,
              ],
              rows: pageRows,
              rowKey: (r) => r.key,
              sort: _sort,
              onSort: (id) => setState(() => _sort = TableSort.next(_sort, id)),
              loading: loading,
              loadingMessage: 'Loading inventory…',
              errorMessage: report.status == LoadStatus.failed
                  ? report.error
                  : null,
              onRetry: _refresh,
              emptyTitle: _filters.activeCount > 0 || _filters.search.isNotEmpty
                  ? 'No inventory items match your filters.'
                  : 'No inventory items yet.',
              emptyMessage: _filters.activeCount > 0
                  ? 'Try removing a filter, or clear them all.'
                  : null,
              selectedKeys: _selected,
              allSelected: allSelected,
              someSelected: _selected.isNotEmpty && !allSelected,
              onToggleRow: (r) => setState(() {
                if (!_selected.remove(r.key)) _selected.add(r.key);
                _selected = {..._selected};
              }),
              // Select-all covers every filtered row, not only this page.
              onToggleAll: (select) => setState(
                () => _selected = select
                    ? {for (final r in displayed) r.key}
                    : {},
              ),
              rowActions: (context, r) =>
                  RowActionMenu(items: _rowItems(context, r, code, busy)),
              actionsWidth: 64,
              footerLabel: widget.reportMode
                  ? null
                  : (selectedRows.isNotEmpty
                        ? 'Totals — ${selectedRows.length} selected rows'
                        : 'Totals — all ${displayed.length} rows'),
              footerRows: widget.reportMode ? null : totalsSource,
              cardBuilder: (context, r) => _card(context, r, code, busy),
            ),
            if (!widget.reportMode) ...[
              const SizedBox(height: AppSpacing.md),
              AppPaginationBar(
                storageKey: _storageKey,
                state: _page,
                total: displayed.length,
                onChanged: (p) => setState(() => _page = p),
              ),
            ],
          ],
        );
      }),
    );
  }

  List<RowMenuItem> _rowItems(
    BuildContext context,
    InventoryReportRow r,
    String code,
    bool busy,
  ) => [
    RowMenuItem(
      label: 'View details',
      icon: Icons.visibility_outlined,
      onSelected: () =>
          showSerialDetailsDialog(context, row: r, currencyCode: code),
    ),
    RowMenuItem(
      label: 'Delete',
      icon: Icons.delete_outline,
      danger: true,
      enabled: !busy,
      onSelected: () => _deleteOne(r),
    ),
  ];

  // ───────── header / actions ─────────

  Widget _header(BuildContext context) {
    if (widget.reportMode) {
      return ScreenHeader(
        title: 'Inventory Report',
        subtitle: 'Full per-serial breakdown of every inventory item',
        icon: Icons.bar_chart,
        iconColor: const Color(0xFF7C3AED),
        onBack: () => Get.offNamed(AppRoutes.inventory),
      );
    }
    return ScreenHeader(
      title: 'Inventory',
      subtitle: 'Per-serial inventory with sales, costs and payment tracking',
      icon: Icons.inventory_2_outlined,
      iconColor: AppColors.sidebar,
      actions: [
        AppButton(
          label: 'Product list',
          icon: Icons.view_list_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => Get.offNamed(AppRoutes.inventoryView),
        ),
      ],
    );
  }

  /// React exports every filtered row (not just the page or the selection),
  /// with all 15 data columns regardless of column visibility.
  ExportTable _exportTable(List<InventoryReportRow> rows, String code) {
    return ExportTable(
      title: widget.reportMode ? 'Inventory Report' : 'Inventory',
      subtitle: '${rows.length} records',
      filters: [for (final f in _activeFilters()) f.label],
      headers: [
        'Stock-In Date (Auto)',
        'Stock-In Date (Manual)',
        'Type',
        'Brand',
        'Model',
        'Serial No.',
        'Location',
        'Ownership',
        'Condition',
        'Status',
        'Sold Date',
        'Invoice #',
        'Supplier Cost ($code)',
        'Purchasing Cost ($code)',
        'Sold Goods Payment',
      ],
      rightAlignedColumns: const {12, 13},
      rows: [
        for (final r in rows)
          [
            formatDate(r.stockInDateAuto),
            formatDate(r.stockInDateManual),
            r.type.isEmpty ? '—' : r.type,
            r.brandName,
            r.modelName,
            r.serialNumber.isEmpty ? '—' : r.serialNumber,
            r.location.isEmpty ? '—' : r.location,
            r.ownership?.label ?? '—',
            r.condition,
            r.currentStatus.label,
            r.currentStatus == StockState.sold ? formatDate(r.soldDate) : '—',
            r.invoiceNumber ?? '—',
            r.supplierCost,
            r.purchasingCost,
            r.supplierPaymentStatus?.label ?? '—',
          ],
      ],
    );
  }

  Widget _quickActions(BuildContext context, AuthUser? user) {
    final actions = [
      (
        Icons.add,
        'Add New',
        AppRoutes.inventoryCreate,
        Screens.inventoryTypeSelection,
        AppColors.primary,
        const Color(0xFFF1F5F9),
      ),
      (
        Icons.rotate_left,
        'Add Returned',
        AppRoutes.inventoryAddReturned,
        Screens.inventoryAddReturned,
        AppColors.warning,
        AppColors.warningSoft,
      ),
      (
        Icons.swap_horiz,
        'Transfer',
        AppRoutes.productTransfer,
        Screens.createProductTransfer,
        AppColors.info,
        AppColors.infoSoft,
      ),
      (
        Icons.warning_amber_rounded,
        'Damaged',
        AppRoutes.inventoryDamaged,
        Screens.damagedInventory,
        AppColors.error,
        AppColors.errorSoft,
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Payables',
        AppRoutes.inventoryPayables,
        Screens.inventoryPayables,
        AppColors.warning,
        AppColors.warningSoft,
      ),
      (
        Icons.delete_outline,
        'Deleted',
        AppRoutes.inventoryDeleted,
        Screens.deletedInventory,
        AppColors.textMuted,
        AppColors.surfaceMuted,
      ),
    ];
    final visible = [
      for (final a in actions)
        if (user?.canAccess(a.$4) ?? false) a,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        // Two per row on phones, otherwise sized to their label.
        final twoUp = c.maxWidth < 560;
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (icon, label, path, _, fg, bg) in visible)
              SizedBox(
                width: twoUp ? w : null,
                child: _QuickAction(
                  icon: icon,
                  label: label,
                  color: fg,
                  background: bg,
                  onTap: () => Get.offNamed(path),
                ),
              ),
          ],
        );
      },
    );
  }

  // ───────── filters ─────────

  List<ActiveFilter> _activeFilters() {
    final f = _filters;
    ReportFilters without({
      Set<String>? brands,
      Set<String>? models,
      Set<String>? types,
      Set<String>? locations,
      Set<String>? conditions,
      Set<String>? statuses,
      Set<String>? ownerships,
      bool clearFrom = false,
      bool clearTo = false,
    }) => f.copyWith(
      brands: brands,
      models: models,
      types: types,
      locations: locations,
      conditions: conditions,
      statuses: statuses,
      ownerships: ownerships,
      dateFrom: clearFrom ? null : f.dateFrom,
      dateTo: clearTo ? null : f.dateTo,
    );
    return [
      if (f.brands.isNotEmpty)
        ActiveFilter(
          filterLabel('Brand', f.brands),
          () => _setFilters(without(brands: {}, models: {})),
        ),
      if (f.models.isNotEmpty)
        ActiveFilter(
          filterLabel('Model', f.models),
          () => _setFilters(without(models: {})),
        ),
      if (f.types.isNotEmpty)
        ActiveFilter(
          filterLabel('Type', f.types),
          () => _setFilters(without(types: {})),
        ),
      if (f.locations.isNotEmpty)
        ActiveFilter(
          filterLabel('Location', f.locations),
          () => _setFilters(without(locations: {})),
        ),
      if (f.conditions.isNotEmpty)
        ActiveFilter(
          filterLabel('Condition', f.conditions),
          () => _setFilters(without(conditions: {})),
        ),
      if (f.statuses.isNotEmpty)
        ActiveFilter(
          filterLabel('Status', f.statuses),
          () => _setFilters(without(statuses: {})),
        ),
      if (f.ownerships.isNotEmpty)
        ActiveFilter(
          filterLabel('Ownership', f.ownerships),
          () => _setFilters(without(ownerships: {})),
        ),
      if (f.dateFrom != null)
        ActiveFilter(
          'From: ${formatDate(f.dateFrom)}',
          () => _setFilters(without(clearFrom: true)),
        ),
      if (f.dateTo != null)
        ActiveFilter(
          'To: ${formatDate(f.dateTo)}',
          () => _setFilters(without(clearTo: true)),
        ),
    ];
  }

  void _openFilters(BuildContext context, List<InventoryReportRow> all) {
    if (_compact) {
      showFilterSheet(
        context,
        title: 'Filters',
        onClearAll: () => _setFilters(ReportFilters.empty),
        fields: (ctx, refresh) =>
            _filterFields(ctx, all, columns: 1, after: refresh),
      );
    } else {
      setState(() => _showFilters = !_showFilters);
    }
  }

  Widget _filterPanel(BuildContext context, List<InventoryReportRow> all) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: _filterFields(context, all),
    );
  }

  /// The 9 filter fields on an even grid ([columns] null = as many as fit).
  Widget _filterFields(
    BuildContext context,
    List<InventoryReportRow> all, {
    int? columns,
    VoidCallback? after,
  }) {
    void set(ReportFilters f) {
      _setFilters(f);
      after?.call();
    }

    final brands = distinctSorted(all.map((r) => r.brandName));
    // Model options cascade from the selected brands.
    final models = distinctSorted(
      all
          .where(
            (r) =>
                _filters.brands.isEmpty ||
                _filters.brands.contains(r.brandName),
          )
          .map((r) => r.modelName),
    );
    final fields = <Widget>[
      MultiSelectField(
        label: 'Brand',
        options: brands,
        selected: _filters.brands,
        // Changing brand clears the model selection (as React).
        onChanged: (v) => set(_filters.copyWith(brands: v, models: {})),
      ),
      MultiSelectField(
        label: 'Model',
        options: models,
        selected: _filters.models.intersection(models.toSet()),
        onChanged: (v) => set(_filters.copyWith(models: v)),
      ),
      MultiSelectField(
        label: 'Type',
        options: distinctSorted(all.map((r) => r.type)),
        selected: _filters.types,
        onChanged: (v) => set(_filters.copyWith(types: v)),
      ),
      MultiSelectField(
        label: 'Location',
        options: distinctSorted(all.map((r) => r.location)),
        selected: _filters.locations,
        onChanged: (v) => set(_filters.copyWith(locations: v)),
      ),
      MultiSelectField(
        label: 'Condition',
        options: ReportFilters.conditionOptions,
        selected: _filters.conditions,
        onChanged: (v) => set(_filters.copyWith(conditions: v)),
      ),
      MultiSelectField(
        label: 'Status',
        options: ReportFilters.statusOptions,
        selected: _filters.statuses,
        onChanged: (v) => set(_filters.copyWith(statuses: v)),
      ),
      MultiSelectField(
        label: 'Ownership',
        options: ReportFilters.ownershipOptions,
        selected: _filters.ownerships,
        onChanged: (v) => set(_filters.copyWith(ownerships: v)),
      ),
      _DateField(
        label: 'From date',
        value: _filters.dateFrom,
        onChanged: (d) => set(_filters.copyWith(dateFrom: d)),
      ),
      _DateField(
        label: 'To date',
        value: _filters.dateTo,
        onChanged: (d) => set(_filters.copyWith(dateTo: d)),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.lg;
        final cols = columns ?? (c.maxWidth / 230).floor().clamp(1, 5);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final f in fields) SizedBox(width: w, child: f)],
        );
      },
    );
  }

  // ───────── table ─────────

  Widget _tableHeader(
    BuildContext context,
    List<InventoryReportRow> displayed,
    List<InventoryReportRow> selectedRows,
    bool busy,
    bool loading,
  ) {
    final t = Theme.of(context).textTheme;
    final n = displayed.length;
    final count = selectedRows.isNotEmpty
        ? '${selectedRows.length} selected of $n'
        : '$n item${n == 1 ? '' : 's'}';
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            text: 'Inventory ',
            style: t.titleSmall,
            children: [
              if (!loading)
                TextSpan(
                  text: count,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        if (selectedRows.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => setState(() => _selected = {}),
                child: const Text('Clear selection'),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Delete (${selectedRows.length})',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.danger,
                onPressed: busy ? null : () => _deleteSelected(selectedRows),
              ),
            ],
          ),
      ],
    );
  }

  /// All columns (visibility is applied when rendering). Widths leave room for
  /// the values, e.g. "Abu Dhabi Showroom".
  List<AppColumn<InventoryReportRow>> _columns(String code) {
    Widget money(double? v) => Text(
      v == null ? '—' : formatCurrency(v, code),
      style: AppTypography.amount,
    );
    Widget footMoney(double v, {Color color = AppColors.textPrimary}) => Text(
      v > 0 ? formatCurrency(v, code) : '—',
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
    Widget place(String s) => s.isEmpty
        ? const Text('—')
        : Tooltip(
            message: s,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Flexible(child: Text(s, overflow: TextOverflow.ellipsis)),
              ],
            ),
          );

    return [
      AppColumn(
        id: 'stockAuto',
        header: _columnHeaders['stockAuto']!,
        width: 170,
        sortValue: (r) => r.stockInDateAuto,
        cell: (_, r) => Text(formatDate(r.stockInDateAuto)),
      ),
      AppColumn(
        id: 'stockManual',
        header: _columnHeaders['stockManual']!,
        width: 190,
        sortValue: (r) => r.stockInDateManual,
        cell: (_, r) => Tooltip(
          message: r.stockInDateManual != null
              ? 'Manual override — user-entered stock-in date'
              : 'No manual override — auto date is the source of truth',
          child: Text(
            formatDate(r.stockInDateManual),
            style: TextStyle(
              color: r.stockInDateManual != null
                  ? AppColors.textPrimary
                  : AppColors.textDisabled,
              fontWeight: r.stockInDateManual != null
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
      AppColumn(
        id: 'type',
        header: _columnHeaders['type']!,
        width: 160,
        sortValue: (r) => r.type.toLowerCase(),
        cell: (_, r) => Text(r.type.isEmpty ? '—' : r.type),
      ),
      AppColumn(
        id: 'brand',
        header: _columnHeaders['brand']!,
        width: 130,
        sortValue: (r) => r.brandName.toLowerCase(),
        cell: (_, r) => Text(
          r.brandName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      AppColumn(
        id: 'model',
        header: _columnHeaders['model']!,
        width: 200,
        sortValue: (r) => r.modelName.toLowerCase(),
        cell: (_, r) => Text(r.modelName, overflow: TextOverflow.ellipsis),
      ),
      AppColumn(
        id: 'serial',
        header: _columnHeaders['serial']!,
        width: 150,
        sortValue: (r) => r.serialNumber.toLowerCase(),
        cell: (_, r) => Text(
          r.serialNumber.isEmpty ? '—' : r.serialNumber,
          style: AppTypography.mono,
        ),
      ),
      AppColumn(
        id: 'location',
        header: _columnHeaders['location']!,
        width: 210,
        sortValue: (r) => r.location.toLowerCase(),
        cell: (_, r) => place(r.location),
      ),
      AppColumn(
        id: 'ownership',
        header: _columnHeaders['ownership']!,
        width: 120,
        sortValue: (r) => r.ownership?.label,
        cell: (_, r) => InventoryBadges.ownership(r.ownership),
      ),
      AppColumn(
        id: 'condition',
        header: _columnHeaders['condition']!,
        width: 120,
        sortValue: (r) => r.condition,
        cell: (_, r) => InventoryBadges.condition(r.condition),
      ),
      AppColumn(
        id: 'status',
        header: _columnHeaders['status']!,
        width: 120,
        sortValue: (r) => r.currentStatus.label,
        cell: (_, r) => InventoryBadges.stockState(r.currentStatus),
      ),
      AppColumn(
        id: 'soldDate',
        header: _columnHeaders['soldDate']!,
        width: 150,
        sortValue: (r) =>
            r.currentStatus == StockState.sold ? r.soldDate : null,
        cell: (_, r) => Text(
          r.currentStatus == StockState.sold ? formatDate(r.soldDate) : '—',
        ),
      ),
      AppColumn(
        id: 'invoice',
        header: _columnHeaders['invoice']!,
        width: 140,
        sortValue: (r) => r.invoiceNumber,
        cell: (_, r) => Text(
          r.currentStatus == StockState.sold && r.invoiceNumber != null
              ? r.invoiceNumber!
              : '—',
          style: AppTypography.mono,
        ),
      ),
      AppColumn(
        id: 'supplierCost',
        header: _columnHeaders['supplierCost']!,
        width: 170,
        alignRight: true,
        sortValue: (r) => r.supplierCost,
        cell: (_, r) => money(r.supplierCost),
        footer: (_, rows) => Align(
          alignment: Alignment.centerRight,
          child: footMoney(rows.fold(0.0, (s, r) => s + (r.supplierCost ?? 0))),
        ),
      ),
      AppColumn(
        id: 'purchasingCost',
        header: _columnHeaders['purchasingCost']!,
        width: 180,
        alignRight: true,
        sortValue: (r) => r.purchasingCost,
        cell: (_, r) => money(r.purchasingCost),
        footer: (_, rows) => Align(
          alignment: Alignment.centerRight,
          child: footMoney(
            rows.fold(0.0, (s, r) => s + (r.purchasingCost ?? 0)),
          ),
        ),
      ),
      AppColumn(
        id: 'payment',
        header: _columnHeaders['payment']!,
        width: 190,
        sortValue: (r) => r.supplierPaymentStatus?.label,
        cell: (_, r) => InventoryBadges.payment(r.supplierPaymentStatus),
        // React: the cell is a status badge, the footer is the paid total.
        footer: (_, rows) => footMoney(
          rows.fold(0.0, (s, r) => s + (r.supplierPaidAmount ?? 0)),
          color: AppColors.success,
        ),
      ),
    ];
  }

  Widget _card(
    BuildContext context,
    InventoryReportRow r,
    String code,
    bool busy,
  ) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _selected.contains(r.key),
                  onChanged: (_) => setState(() {
                    if (!_selected.remove(r.key)) _selected.add(r.key);
                    _selected = {..._selected};
                  }),
                ),
                Expanded(
                  child: Text(
                    '${r.brandName} ${r.modelName}',
                    style: t.titleSmall,
                  ),
                ),
                RowActionMenu(items: _rowItems(context, r, code, busy)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      InventoryBadges.stockState(r.currentStatus),
                      InventoryBadges.condition(r.condition),
                      InventoryBadges.ownership(r.ownership),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _kv(
                    t,
                    'Serial',
                    r.serialNumber.isEmpty ? '—' : r.serialNumber,
                    mono: true,
                  ),
                  _kv(t, 'Location', r.location.isEmpty ? '—' : r.location),
                  _kv(t, 'Stock-in', formatDate(r.stockInDateAuto)),
                  if (r.currentStatus == StockState.sold)
                    _kv(
                      t,
                      'Sold',
                      '${formatDate(r.soldDate)}  ·  ${r.invoiceNumber ?? '—'}',
                    ),
                  _kv(
                    t,
                    'Supplier cost',
                    r.supplierCost == null
                        ? '—'
                        : formatCurrency(r.supplierCost!, code),
                  ),
                  _kv(
                    t,
                    'Purchasing cost',
                    r.purchasingCost == null
                        ? '—'
                        : formatCurrency(r.purchasingCost!, code),
                  ),
                  if (r.supplierPaymentStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Row(
                        children: [
                          Text(
                            'Payment',
                            style: t.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          InventoryBadges.payment(r.supplierPaymentStatus),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(TextTheme t, String k, String v, {bool mono = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            k,
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(v, style: mono ? AppTypography.mono : t.bodySmall),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Container(
        // Sizes to its label (never truncated); light 1px outline.
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          button: true,
          label: '$label, ${value == null ? 'not set' : formatDate(value)}',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              height: AppDimensions.fieldHeight - 4,
              padding: const EdgeInsets.only(left: AppSpacing.md),
              decoration: BoxDecoration(
                color: value != null
                    ? AppColors.surfaceMuted
                    : AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value == null ? 'Any' : formatDate(value),
                      style: t.bodyMedium?.copyWith(
                        color: value == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (value != null)
                    IconButton(
                      tooltip: 'Clear $label',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => onChanged(null),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.md),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
