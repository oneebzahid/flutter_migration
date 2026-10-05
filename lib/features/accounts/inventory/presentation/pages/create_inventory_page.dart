import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/widgets/form_section.dart';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/widgets/currency_picker.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../domain/rules/add_inventory_rules.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/product.dart';
import '../controllers/create_inventory_controller.dart';
import '../widgets/entry_row_card.dart';

/// Add Inventory (React `/inventory/create-new`): the unified entry form.
///
/// Owned stock is entered from a purchase shipment (landed cost per unit,
/// retail suggested at a margin); Credit stock is entered by hand and recorded
/// as a supplier payable. Payment is tracked separately (saved as unpaid).
///
/// Not migrated: product image upload (needs a file picker).
class AddInventoryPage extends StatefulWidget {
  const AddInventoryPage({super.key});

  @override
  State<AddInventoryPage> createState() => _AddInventoryPageState();
}

class _AddInventoryPageState extends State<AddInventoryPage> {
  bool _credit = false;
  String? _shipmentId;
  final _margin = TextEditingController(
    text: kDefaultMarginPercent.toStringAsFixed(0),
  );
  final List<EntryRow> _rows = [EntryRow()];
  Map<int, Map<String, String>> _errors = {};
  List<int> _missingLocation = [];
  String? _saveError;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _margin.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  final CreateInventoryController _c = Get.find<CreateInventoryController>();

  double get _marginValue => double.tryParse(_margin.text.trim()) ?? 0;

  Shipment? _shipment() =>
      _c.shipments.value.items.where((x) => x.id == _shipmentId).firstOrNull;

  void _refresh() => setState(() {});

  // ───────── ownership / shipment ─────────

  void _setOwnership(bool credit) {
    if (credit == _credit) return;
    setState(() {
      _credit = credit;
      if (credit) {
        // Credit stock is entered by hand: drop every shipment link.
        _shipmentId = null;
        for (final r in _rows) {
          r
            ..shipmentId = null
            ..line = null
            ..manualModel = false;
        }
      }
    });
  }

  void _attachShipment(Shipment? sh) {
    setState(() {
      _shipmentId = sh?.id;
      for (final r in _rows) {
        r
          ..shipmentId = sh?.id
          ..line = null
          ..manualModel = false
          ..category = ''
          ..model.clear();
        if (sh != null) r.brand.text = sh.brandName;
      }
    });
  }

  /// Changing the margin re-prices every row that has a shipment line.
  void _onMargin(String _) => setState(() {
    for (final r in _rows) {
      final l = r.line;
      if (l != null) {
        r.sell.text = suggestedSellPrice(
          l.landedUnitCost,
          _marginValue,
        ).toStringAsFixed(2);
      }
    }
  });

  void _addRow() => setState(() {
    final sh = _shipment();
    _rows.add(EntryRow(shipmentId: sh?.id, brandName: sh?.brandName ?? ''));
  });

  void _removeRow(int i) => setState(() {
    if (_rows.length > 1) _rows.removeAt(i).dispose();
    _errors = {};
    _missingLocation = [];
  });

  void _onBrandTyped(String brand) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || brand.trim().isEmpty) return;
      _c.loadModels(brand.trim());
    });
  }

  // ───────── save ─────────

  void _save() {
    final data = [for (final r in _rows) r.toData()];
    final v = AddInventoryRules.validate(data);
    setState(() {
      _errors = v.rowErrors;
      _missingLocation = v.missingLocation;
      _saveError = null;
    });
    if (!v.isValid) {
      // One snackbar with every problem (a second would replace the first).
      final messages = [
        for (final i in v.missingLocation)
          'Product ${i + 1}: location is required',
        if (v.hasSerialProblem) 'Fix serial-number errors before saving',
      ];
      if (messages.isNotEmpty) {
        showAppSnackBar(context, messages.join('\n'), isError: true);
      }
      return;
    }
    _c.createProducts([
      for (final r in _rows)
        NewProductDraft(
          brandName: r.brand.text.trim(),
          modelName: r.model.text.trim(),
          category: r.category,
          description: r.description.text.trim(),
          costPrice: r.costValue,
          sellPrice: r.sellValue,
          quantity: r.quantity,
          location: r.location,
          serials: [for (final c in r.serials) c.text],
          ownership: _credit ? OwnershipType.credit : OwnershipType.owned,
          status: r.status,
          stockInDateManual: r.stockInDate,
          shipmentId: r.shipmentId,
          shipmentLineId: r.line?.lineId,
        ),
    ]);
  }

  void _onNotice(Notice n) {
    if (n.tag == 'brand-added' || n.tag == 'model-added') return;
    showAppSnackBar(context, n.message, isError: n.isError);
    if (n.tag == 'create-ok' || n.tag == 'create-partial') {
      Get.offNamed(AppRoutes.inventory);
    } else if (n.tag == 'create-fail') {
      setState(() => _saveError = n.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      showSnackBar: false,
      onNotice: _onNotice,
      child: Obx(() {
        final code = Get.find<CurrencyProvider>().currencyCode.value;
        final saving = _c.saving.value;
        final sh = _shipment();
        final data = [for (final r in _rows) r.toData()];
        final grand = AddInventoryRules.grandTotal(data);
        final t = Theme.of(context).textTheme;

        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            ScreenHeader(
              title: 'Add Inventory',
              subtitle: 'TXN: ${_c.txnId.value ?? '…'}',
              icon: Icons.add,
              onBack: () => Get.offNamed(AppRoutes.inventory),
              actions: const [CurrencyPicker()],
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ownershipCard(context),
                    if (!_credit) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _shipmentCard(context, sh),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    for (var i = 0; i < _rows.length; i++) ...[
                      EntryRowCard(
                        key: _rows[i].key,
                        row: _rows[i],
                        index: i,
                        total: _rows.length,
                        isCredit: _credit,
                        code: code,
                        errors: _errors[i] ?? const {},
                        brands: _c.brands.value.items,
                        models: _c.modelsFor(_rows[i].brand.text.trim()).items,
                        shipment: sh,
                        marginPercent: _marginValue,
                        locationMissing: _missingLocation.contains(i),
                        onChanged: _refresh,
                        onRemove: () => _removeRow(i),
                        onBrandTyped: _onBrandTyped,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    OutlinedButton.icon(
                      onPressed: saving ? null : () => _addRow(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Product'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        'Payment tracked separately. This inventory will be saved as unpaid'
                        '${_credit ? ' and appear in Inventory Payables' : ''}. '
                        'Record payment later from the Transactions module.',
                        style: t.bodySmall?.copyWith(color: AppColors.info),
                      ),
                    ),
                    if (grand > 0) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.sidebar,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Grand Total — ${_rows.length} product${_rows.length == 1 ? '' : 's'}',
                                style: t.labelLarge?.copyWith(
                                  color: AppColors.sidebarText,
                                ),
                              ),
                            ),
                            Text(
                              formatCurrency(grand, code),
                              style: t.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_saveError != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Save Failed',
                                    style: t.labelLarge?.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  Text(
                                    _saveError!,
                                    style: t.bodySmall?.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: () =>
                                  setState(() => _saveError = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: AppSpacing.md,
                      children: [
                        AppButton(
                          label: 'Cancel',
                          icon: Icons.arrow_back,
                          variant: AppButtonVariant.secondary,
                          onPressed: saving
                              ? null
                              : () => Get.offNamed(AppRoutes.inventory),
                        ),
                        AppButton(
                          label: _rows.length > 1
                              ? 'Save All ${_rows.length} Products'
                              : 'Save Inventory',
                          icon: Icons.check,
                          variant: AppButtonVariant.success,
                          isLoading: saving,
                          onPressed: saving ? null : _save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ───────── cards ─────────

  Widget _ownershipCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget option({
      required bool credit,
      required IconData icon,
      required Color color,
      required String title,
      required String sub,
    }) {
      final selected = _credit == credit;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _setOwnership(credit),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.titleSmall?.copyWith(
                          color: selected ? color : null,
                        ),
                      ),
                      Text(
                        sub,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    return FormCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ownership Type', style: t.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                option(
                  credit: false,
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.success,
                  title: 'Owned Inventory',
                  sub: 'Paying supplier now',
                ),
                const SizedBox(width: AppSpacing.md),
                option(
                  credit: true,
                  icon: Icons.groups_outlined,
                  color: AppColors.warning,
                  title: 'Third-party Inventory',
                  sub: 'Pay supplier later',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shipmentCard(BuildContext context, Shipment? sh) {
    final t = Theme.of(context).textTheme;
    final list = _c.shipments.value;
    final loading =
        list.status == LoadStatus.idle || list.status == LoadStatus.loading;
    return FormCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipment', style: t.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'Pick a shipment',
                          style: t.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          children: const [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      DropdownButtonFormField<String>(
                        key: ValueKey('ship-$_shipmentId-${list.items.length}'),
                        initialValue: _shipmentId,
                        isExpanded: true,
                        hint: Text(
                          loading
                              ? 'Loading shipments…'
                              : (list.items.isEmpty
                                    ? 'No shipments found'
                                    : '— select shipment —'),
                        ),
                        items: [
                          for (final s in list.items)
                            DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: list.items.isEmpty
                            ? null
                            : (v) => _attachShipment(
                                list.items.where((x) => x.id == v).firstOrNull,
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Margin %',
                        style: t.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      TextField(
                        controller: _margin,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: _onMargin,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sh != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'One row per line, filled with what is still on the order. The purchasing cost '
                  'is the landed figure from the shipment; retail is filled at '
                  '${_margin.text.trim().isEmpty ? '0' : _margin.text.trim()}% and stays editable, '
                  'but never below cost.',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
