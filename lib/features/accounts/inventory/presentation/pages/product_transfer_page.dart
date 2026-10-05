import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../../core/config/brand_assets.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/file_downloader.dart';
import '../../../../../core/utils/table_export.dart';
import '../../../../../core/widgets/active_filter_chips.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_data_table.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_pagination_bar.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/export_menu.dart';
import '../../../../../core/widgets/filter_sheet.dart';
import '../../../../../core/widgets/multi_select_field.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../../../../core/widgets/row_action_menu.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/widgets/stat_card.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../../../../core/widgets/table_toolbar.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../domain/entities/product_transfer.dart';
import '../controllers/product_transfer_controller.dart';
import '../utils/transfer_note_pdf.dart';

/// Product Transfer list (React `/product-transfer`): stat tiles + table with
/// Dispatch / Receive / Cancel / Download note / Delete row actions.
class ProductTransferPage extends StatefulWidget {
  const ProductTransferPage({super.key});

  @override
  State<ProductTransferPage> createState() => _ProductTransferPageState();
}

class _ProductTransferPageState extends State<ProductTransferPage> {
  static const _storageKey = 'inventory.transfers';

  String _search = '';
  Set<String> _status = {};
  Set<String> _routes = {};
  late PageState _page = PageState.restore(_storageKey);
  TableSort? _sort;
  bool _showFilters = false;

  final ProductTransferController _c = Get.find<ProductTransferController>();

  bool get _compact => MediaQuery.sizeOf(context).width < 720;

  void _filtersChanged(VoidCallback f) => setState(() {
    f();
    _page = _page.copyWith(page: 1);
  });

  List<ProductTransfer> _filter(List<ProductTransfer> all) {
    final q = _search.trim().toLowerCase();
    return [
      for (final t in all)
        if ((_status.isEmpty || _status.contains(t.status.label)) &&
            (_routes.isEmpty ||
                _routes.contains(t.from) ||
                _routes.contains(t.to)) &&
            (q.isEmpty ||
                t.id.toLowerCase().contains(q) ||
                t.productLabel.toLowerCase().contains(q) ||
                t.from.toLowerCase().contains(q) ||
                t.to.toLowerCase().contains(q) ||
                t.transferredBy.toLowerCase().contains(q) ||
                t.serials.any((s) => s.toLowerCase().contains(q))))
          t,
    ];
  }

  String _dt(DateTime d) => formatDateTime(d);

  StatusTone _tone(TransferStatus s) => switch (s) {
    TransferStatus.pending => StatusTone.warning,
    TransferStatus.inTransit => StatusTone.info,
    TransferStatus.received => StatusTone.success,
    TransferStatus.cancelled => StatusTone.neutral,
  };

  // ───────── actions ─────────

  Future<void> _receive(ProductTransfer t) async {
    final email = Get.find<SessionProvider>().currentUser?.email ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ReceiveDialog(transfer: t, initial: email),
    );
    if (name != null && mounted) {
      _c.receive(t.id, name);
    }
  }

  Future<void> _dispatchOne(ProductTransfer t) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Dispatch this transfer?',
      message:
          '${t.productLabel} · ${t.quantity} unit(s)\n${t.from} → ${t.to}\n\n'
          'The serials become In Transit and leave available stock until received.',
      confirmLabel: 'Dispatch',
    );
    if (ok && mounted) {
      _c.dispatch(t.id);
    }
  }

  Future<void> _cancel(ProductTransfer t) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel this transfer?',
      message: t.status == TransferStatus.inTransit
          ? 'The ${t.quantity} unit(s) return to available stock at ${t.from}.'
          : 'The reservation on ${t.quantity} unit(s) is released.',
      confirmLabel: 'Cancel transfer',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (ok && mounted) {
      _c.cancel(t.id);
    }
  }

  Future<void> _delete(ProductTransfer t) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this transfer record?',
      message: switch (t.status) {
        TransferStatus.received =>
          'The record is removed and the ${t.quantity} unit(s) are moved back '
              'to ${t.from}.',
        TransferStatus.inTransit || TransferStatus.pending =>
          'The record is removed and its units become available again at ${t.from}.',
        TransferStatus.cancelled => 'The cancelled record is removed.',
      },
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && mounted) {
      _c.deleteTransfer(t.id);
    }
  }

  Future<void> _download(ProductTransfer t) async {
    try {
      Uint8List? logo;
      try {
        logo = (await rootBundle.load(BrandAssets.logo)).buffer.asUint8List();
      } catch (_) {}
      final bytes = await TransferNotePdf.build(t, logo: logo);
      await AppFileDownloader.instance.save(
        fileName: 'transfer-${t.id}',
        extension: 'pdf',
        bytes: bytes,
      );
      if (mounted) showAppSnackBar(context, 'Transfer note downloaded');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not create the transfer note. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _view(ProductTransfer t, String code) => showDialog<void>(
    context: context,
    builder: (_) => _DetailsDialog(transfer: t, code: code, fmt: _dt),
  );

  List<RowMenuItem> _items(ProductTransfer t, String code, bool busy) => [
    RowMenuItem(
      label: 'View details',
      icon: Icons.visibility_outlined,
      onSelected: () => _view(t, code),
    ),
    if (t.canDispatch)
      RowMenuItem(
        label: 'Dispatch',
        icon: Icons.local_shipping_outlined,
        enabled: !busy,
        onSelected: () => _dispatchOne(t),
      ),
    if (t.canReceive)
      RowMenuItem(
        label: 'Receive',
        icon: Icons.move_to_inbox_outlined,
        enabled: !busy,
        onSelected: () => _receive(t),
      ),
    RowMenuItem(
      label: 'Download PDF',
      icon: Icons.picture_as_pdf_outlined,
      onSelected: () => _download(t),
    ),
    if (t.canCancel)
      RowMenuItem(
        label: 'Cancel transfer',
        icon: Icons.block,
        enabled: !busy,
        onSelected: () => _cancel(t),
      ),
    RowMenuItem(
      label: 'Delete',
      icon: Icons.delete_outline,
      danger: true,
      enabled: !busy,
      onSelected: () => _delete(t),
    ),
  ];

  // ───────── build ─────────

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      child: Obx(() {
        final list = _c.transfers.value;
        final busy = _c.busy.value;
        final code = Get.find<CurrencyProvider>().currencyCode.value;
        final loading = list.isInitialLoading;
        final columns = _columns(code);
        final rows = TableSort.apply(_filter(list.items), columns, _sort);
        final pageRows = _page.slice(rows);
        int count(TransferStatus s) =>
            list.items.where((t) => t.status == s).length;

        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            ScreenHeader(
              title: 'Product Transfer',
              subtitle: 'Move stock between locations and track receipt',
              icon: Icons.swap_horiz,
              iconColor: AppColors.info,
              onBack: () => Get.offNamed(AppRoutes.inventory),
              actions: [
                AppButton(
                  label: 'New transfer',
                  icon: Icons.add,
                  onPressed: () => Get.offNamed(AppRoutes.productTransferNew),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                StatCard(label: 'Total', value: '${list.items.length}'),
                StatCard(
                  label: 'Pending',
                  value: '${count(TransferStatus.pending)}',
                  color: AppColors.warning,
                ),
                StatCard(
                  label: 'In Transit',
                  value: '${count(TransferStatus.inTransit)}',
                  color: AppColors.info,
                ),
                StatCard(
                  label: 'Received',
                  value: '${count(TransferStatus.received)}',
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TableToolbar(
              searchHint: 'Search transfer, product, serial, location…',
              onSearch: (v) => _filtersChanged(() => _search = v),
              filterCount:
                  (_status.isEmpty ? 0 : 1) + (_routes.isEmpty ? 0 : 1),
              filtersOpen: _showFilters,
              onOpenFilters: () => _openFilters(context, list.items),
              onRefresh: () => _c.load(),
              export: ExportSpec(
                fileBaseName: 'product-transfers',
                rowCount: rows.length,
                build: () => _exportTable(rows, code),
              ),
            ),
            if (_showFilters && !_compact) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: _filterFields(list.items),
              ),
            ],
            if (_status.isNotEmpty || _routes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ActiveFilterChips(
                filters: [
                  if (_status.isNotEmpty)
                    ActiveFilter(
                      filterLabel('Status', _status),
                      () => _filtersChanged(() => _status = {}),
                    ),
                  if (_routes.isNotEmpty)
                    ActiveFilter(
                      filterLabel('Location', _routes),
                      () => _filtersChanged(() => _routes = {}),
                    ),
                ],
                onClearAll: () => _filtersChanged(() {
                  _status = {};
                  _routes = {};
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppDataTable<ProductTransfer>(
              columns: columns,
              rows: pageRows,
              rowKey: (t) => t.id,
              sort: _sort,
              onSort: (id) => setState(() => _sort = TableSort.next(_sort, id)),
              loading: loading,
              loadingMessage: 'Loading transfers…',
              errorMessage: list.status == LoadStatus.failed
                  ? list.error
                  : null,
              onRetry: () => _c.load(),
              emptyTitle: list.items.isEmpty
                  ? 'No transfers yet.'
                  : 'No transfers match your filters.',
              emptyMessage: list.items.isEmpty
                  ? 'Create one with “New transfer”.'
                  : null,
              rowActions: (context, t) =>
                  RowActionMenu(items: _items(t, code, busy)),
              actionsWidth: 64,
              cardBuilder: (context, t) => _card(context, t, code, busy),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPaginationBar(
              storageKey: _storageKey,
              state: _page,
              total: rows.length,
              onChanged: (p) => setState(() => _page = p),
            ),
          ],
        );
      }),
    );
  }

  void _openFilters(BuildContext context, List<ProductTransfer> all) {
    if (_compact) {
      showFilterSheet(
        context,
        title: 'Filters',
        onClearAll: () => _filtersChanged(() {
          _status = {};
          _routes = {};
        }),
        fields: (ctx, refresh) =>
            _filterFields(all, columns: 1, after: refresh),
      );
    } else {
      setState(() => _showFilters = !_showFilters);
    }
  }

  Widget _filterFields(
    List<ProductTransfer> all, {
    int columns = 2,
    VoidCallback? after,
  }) {
    final places = {
      for (final t in all) ...[t.from, t.to],
    }.toList()..sort();
    final fields = [
      MultiSelectField(
        label: 'Status',
        options: [for (final s in TransferStatus.values) s.label],
        selected: _status,
        onChanged: (v) {
          _filtersChanged(() => _status = v);
          after?.call();
        },
      ),
      MultiSelectField(
        label: 'Location (from or to)',
        options: places,
        selected: _routes,
        onChanged: (v) {
          _filtersChanged(() => _routes = v);
          after?.call();
        },
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.lg;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final f in fields) SizedBox(width: w, child: f)],
        );
      },
    );
  }

  ExportTable _exportTable(List<ProductTransfer> rows, String code) =>
      ExportTable(
        title: 'Product Transfers',
        subtitle: '${rows.length} transfers',
        filters: [
          if (_status.isNotEmpty) filterLabel('Status', _status),
          if (_routes.isNotEmpty) filterLabel('Location', _routes),
          if (_search.trim().isNotEmpty) 'Search: ${_search.trim()}',
        ],
        headers: [
          'Transfer',
          'Date & Time',
          'Product',
          'From',
          'To',
          'Qty',
          'Serials',
          'Shipment Cost ($code)',
          'Transferred By',
          'Received By',
          'Status',
        ],
        rightAlignedColumns: const {5, 7},
        rows: [
          for (final t in rows)
            [
              t.id,
              _dt(t.date),
              t.productLabel,
              t.from,
              t.to,
              t.quantity,
              t.serials.join(', '),
              t.shipmentCost,
              t.transferredBy,
              t.receivedBy ?? '—',
              t.status.label,
            ],
        ],
      );

  List<AppColumn<ProductTransfer>> _columns(String code) => [
    AppColumn(
      id: 'date',
      header: 'Date & Time',
      width: 190,
      sortValue: (t) => t.date,
      cell: (_, t) => Text(_dt(t.date)),
    ),
    AppColumn(
      id: 'product',
      header: 'Product',
      width: 240,
      sortValue: (t) => t.productLabel.toLowerCase(),
      cell: (ctx, t) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.productLabel,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            t.id,
            style: Theme.of(ctx).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
    AppColumn(
      id: 'route',
      header: 'Route',
      width: 300,
      sortValue: (t) => '${t.from} ${t.to}'.toLowerCase(),
      cell: (_, t) => Row(
        children: [
          Flexible(child: Text(t.from, overflow: TextOverflow.ellipsis)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
          Flexible(child: Text(t.to, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
    AppColumn(
      id: 'qty',
      header: 'Qty',
      width: 80,
      alignRight: true,
      sortValue: (t) => t.quantity,
      cell: (_, t) => Text('${t.quantity}'),
    ),
    AppColumn(
      id: 'serials',
      header: 'Serials',
      width: 220,
      cell: (_, t) => Tooltip(
        message: t.serials.join(', '),
        child: Text(
          t.serials.join(', '),
          overflow: TextOverflow.ellipsis,
          style: AppTypography.mono,
        ),
      ),
    ),
    AppColumn(
      id: 'cost',
      header: 'Shipment Cost',
      width: 160,
      alignRight: true,
      sortValue: (t) => t.shipmentCost,
      cell: (_, t) =>
          Text(t.shipmentCost > 0 ? formatCurrency(t.shipmentCost, code) : '—'),
    ),
    AppColumn(
      id: 'by',
      header: 'Transferred By',
      width: 170,
      sortValue: (t) => t.transferredBy.toLowerCase(),
      cell: (_, t) => Text(t.transferredBy, overflow: TextOverflow.ellipsis),
    ),
    AppColumn(
      id: 'status',
      header: 'Status',
      width: 130,
      sortValue: (t) => t.status.label,
      cell: (_, t) => StatusBadge(label: t.status.label, tone: _tone(t.status)),
    ),
  ];

  Widget _card(
    BuildContext context,
    ProductTransfer t,
    String code,
    bool busy,
  ) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.productLabel, style: tt.titleSmall)),
                RowActionMenu(items: _items(t, code, busy)),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(label: t.status.label, tone: _tone(t.status)),
                Text(
                  '${t.quantity} unit(s)  ·  ${t.id}',
                  style: tt.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${t.from}  →  ${t.to}', style: tt.bodyMedium),
            Text(
              _dt(t.date),
              style: tt.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.transfer, required this.initial});
  final ProductTransfer transfer;
  final String initial;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter who is receiving the stock.');
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return AppDialog(
      title: 'Receive transfer',
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Mark received', onPressed: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.productLabel} · ${t.quantity} unit(s)\n${t.from} → ${t.to}',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Received by',
            required: true,
            controller: _name,
            autofocus: true,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

class _DetailsDialog extends StatelessWidget {
  const _DetailsDialog({
    required this.transfer,
    required this.code,
    required this.fmt,
  });
  final ProductTransfer transfer;
  final String code;
  final String Function(DateTime) fmt;

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    final tt = Theme.of(context).textTheme;
    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: tt.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
    return AppDialog(
      title: 'Transfer ${t.id}',
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kv('Status', t.status.label),
          kv('Product', t.productLabel),
          kv('Route', '${t.from} → ${t.to}'),
          kv('Date & time', fmt(t.date)),
          kv('Transferred by', t.transferredBy),
          kv('Received by', t.receivedBy ?? '—'),
          if (t.receivedAt != null) kv('Received at', fmt(t.receivedAt!)),
          kv(
            'Shipment cost',
            t.shipmentCost > 0 ? formatCurrency(t.shipmentCost, code) : '—',
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Serials (${t.quantity})', style: tt.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in t.serials)
                Chip(
                  label: Text(s, style: AppTypography.mono),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
