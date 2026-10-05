import 'package:flutter/material.dart';

import '../../../../../core/widgets/form_section.dart';

import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../domain/rules/add_inventory_rules.dart';
import '../../domain/rules/add_stock_rules.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/product.dart';
import 'location_picker.dart';

const kCategories = ['Finished Goods', 'Accessories'];
const _newModelKey = '__new__';

/// Mutable state of one product row on the Add Inventory form.
class EntryRow {
  EntryRow({this.shipmentId, String brandName = ''}) {
    brand.text = brandName;
  }

  final Key key = UniqueKey();
  final brand = TextEditingController();
  final brandFocus = FocusNode();
  final model = TextEditingController();
  final modelFocus = FocusNode();
  final description = TextEditingController();
  final cost = TextEditingController();
  final sell = TextEditingController();
  final List<TextEditingController> serials = [TextEditingController()];
  final qtyController = TextEditingController(text: '1');

  String category = '';
  int _quantity = 1;
  int get quantity => _quantity;

  /// Sets the quantity (min 1), keeping the field and the serial inputs in step.
  set quantity(int v) {
    _quantity = v < 1 ? 1 : v;
    if (qtyController.text != '$_quantity') {
      qtyController.text = '$_quantity';
    }
  }

  String location = '';
  ProductStatus status = ProductStatus.newItem;
  DateTime? stockInDate;

  /// Shipment this row stocks in from (Owned mode), and the chosen line.
  String? shipmentId;
  StockInLine? line;

  /// "+ New model on this shipment (not on the list)".
  bool manualModel = false;

  double get costValue => AddStockRules.parsePrice(cost.text);
  double get sellValue => AddStockRules.parsePrice(sell.text);

  void resizeSerials(int n) {
    while (serials.length < n) {
      serials.add(TextEditingController());
    }
    while (serials.length > n) {
      serials.removeLast().dispose();
    }
  }

  EntryRowData toData() => EntryRowData(
    brand: brand.text,
    model: model.text,
    category: category,
    quantity: quantity,
    costPrice: costValue,
    sellPrice: sellValue,
    serials: [for (final c in serials) c.text],
    location: location,
    hasShipment: shipmentId != null,
    manualModelInShipment: manualModel,
    lineRemaining: line?.remaining,
  );

  void dispose() {
    for (final c in [
      brand,
      model,
      description,
      cost,
      sell,
      qtyController,
      ...serials,
    ]) {
      c.dispose();
    }
    brandFocus.dispose();
    modelFocus.dispose();
  }
}

/// One "Product" card of the Add Inventory form.
class EntryRowCard extends StatelessWidget {
  const EntryRowCard({
    super.key,
    required this.row,
    required this.index,
    required this.total,
    required this.isCredit,
    required this.code,
    required this.errors,
    required this.brands,
    required this.models,
    required this.shipment,
    required this.marginPercent,
    required this.locationMissing,
    required this.onChanged,
    required this.onRemove,
    required this.onBrandTyped,
  });

  final EntryRow row;
  final int index;
  final int total;
  final bool isCredit;
  final String code;
  final Map<String, String> errors;
  final List<String> brands;
  final List<ModelOption> models;

  /// The picked shipment when this row belongs to one.
  final Shipment? shipment;
  final double marginPercent;
  final bool locationMissing;

  /// Call after mutating [row] so the page rebuilds.
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final ValueChanged<String> onBrandTyped;

  bool get _hasShipment => row.shipmentId != null;

  void _pickLine(String? lineId) {
    if (lineId == _newModelKey) {
      row
        ..manualModel = true
        ..line = null
        ..model.clear()
        ..cost.clear();
    } else {
      final l = shipment?.lines.where((x) => x.lineId == lineId).firstOrNull;
      if (l != null) {
        row
          ..manualModel = false
          ..line = l
          ..model.text = l.modelName
          ..quantity = row.quantity < l.remaining ? row.quantity : l.remaining
          ..cost.text = _num(l.landedUnitCost)
          ..sell.text = _num(
            suggestedSellPrice(l.landedUnitCost, marginPercent),
          );
        row.resizeSerials(row.quantity);
      }
    }
    onChanged();
  }

  void _applyModelOption(ModelOption m) {
    row.model.text = m.name;
    if (m.description.isNotEmpty) row.description.text = m.description;
    if (m.category.isNotEmpty) row.category = m.category;
    if ((m.sellPrice ?? 0) > 0) row.sell.text = _num(m.sellPrice!);
    if ((m.costPrice ?? 0) > 0) row.cost.text = _num(m.costPrice!);
    onChanged();
  }

  void _setQty(int q) {
    row.quantity = q < 1 ? 1 : q;
    row.resizeSerials(row.quantity);
    onChanged();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final filled = AddStockRules.filled([for (final c in row.serials) c.text])
        .length;
    final subtotal = row.costValue * (filled == 0 ? row.quantity : filled);
    final line = row.line;

    return FormCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    total > 1 ? 'Product #${index + 1}' : 'Product',
                    style: t.titleSmall,
                  ),
                ),
                if (total > 1)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _two(_brandField(context), _modelField(context)),
            const SizedBox(height: AppSpacing.lg),
            _two(
              _dropdown(
                label: 'Category',
                required: true,
                value: row.category.isEmpty ? null : row.category,
                hint: 'Select…',
                items: kCategories,
                error: errors['category'],
                onChanged: (v) {
                  row.category = v ?? '';
                  onChanged();
                },
              ),
              _qtyField(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Description'),
            TextField(
              controller: row.description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Optional — Enter for a new line\nMade in UK\n3 years warranty',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _two(
              _priceField(
                context,
                label: isCredit ? 'Supplier Cost' : 'Purchasing Cost',
                controller: row.cost,
                error: errors['cost'],
                help: isCredit
                    ? 'What you owe the supplier per unit. Recorded as a payable until settled.'
                    : 'What you paid to buy this stock. Used for internal valuation only.',
              ),
              _priceField(
                context,
                label: 'Retail Price',
                controller: row.sell,
                error: errors['retail'],
                help: 'What customers pay. This is the price that appears on their sales invoice.',
              ),
            ),
            if (line != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _breakdown(context, line),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                _label(context, 'Serial Numbers', required: true),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '(${row.quantity} unit${row.quantity == 1 ? '' : 's'})',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            if (errors['serials'] != null || errors['quantity'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  errors['serials'] ?? errors['quantity']!,
                  style: t.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (var i = 0; i < row.serials.length; i++)
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: row.serials[i],
                      onChanged: (_) => onChanged(),
                      decoration: InputDecoration(
                        hintText: 'Serial #${i + 1}',
                        prefixText: '#${i + 1}  ',
                        // Red outline when the serial list has an error (the
                        // message is shown once, above the inputs).
                        enabledBorder:
                            (errors['serials'] != null ||
                                errors['quantity'] != null)
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (row.costValue > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Subtotal: ${formatCurrency(subtotal, code)} '
                '(${filled == 0 ? row.quantity : filled} unit${(filled == 0 ? row.quantity : filled) == 1 ? '' : 's'})',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const Divider(height: AppSpacing.xxl),
            Text('Stock Settings', style: t.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                SizedBox(
                  width: 260,
                  child: LocationPicker(
                    required: true,
                    value: row.location,
                    errorText: locationMissing ? 'Required' : null,
                    onChanged: (v) {
                      row.location = v;
                      onChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _dropdown(
                    label: 'Condition',
                    value: row.status == ProductStatus.used ? 'Used' : 'New',
                    items: const ['New', 'Used'],
                    onChanged: (v) {
                      row.status = v == 'Used'
                          ? ProductStatus.used
                          : ProductStatus.newItem;
                      onChanged();
                    },
                  ),
                ),
                SizedBox(width: 300, child: _stockInDate(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────── pieces ─────────

  Widget _two(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 640
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: b),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: AppSpacing.lg),
              b,
            ],
          ),
  );

  Widget _label(BuildContext context, String text, {bool required = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
        child: Text.rich(
          TextSpan(
            text: text,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.textSecondary),
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
      );

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
    String? hint,
    String? error,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Builder(builder: (c) => _label(c, label, required: required)),
      DropdownButtonFormField<String>(
        key: ValueKey('$label|$value'),
        initialValue: value,
        isExpanded: true,
        hint: hint == null ? null : Text(hint),
        decoration: InputDecoration(errorText: error),
        items: [
          for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
        ],
        onChanged: onChanged,
      ),
    ],
  );

  Widget _priceField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String help,
    String? error,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: help,
        child: _label(context, '$label ($code)', required: true),
      ),
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          hintText: '0.00',
          prefixText: '$code  ',
          errorText: error,
        ),
      ),
    ],
  );

  Widget _qtyField(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _label(context, 'Qty', required: true),
      Row(
        children: [
          IconButton.outlined(
            tooltip: 'Decrease quantity',
            icon: const Icon(Icons.remove),
            onPressed: () => _setQty(row.quantity - 1),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 90,
            child: TextField(
              controller: row.qtyController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n >= 1 && n != row.quantity) {
                  row.quantity = n;
                  row.resizeSerials(n);
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: 'Increase quantity',
            icon: const Icon(Icons.add),
            onPressed: () => _setQty(row.quantity + 1),
          ),
        ],
      ),
    ],
  );

  Widget _brandField(BuildContext context) {
    if (_hasShipment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Brand', required: true),
          InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.business, size: 18),
              fillColor: AppColors.surfaceMuted,
              errorText: errors['brand'],
            ),
            child: Text(row.brand.text.isEmpty ? '—' : row.brand.text),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Brand', required: true),
        _autocomplete(
          controller: row.brand,
          focus: row.brandFocus,
          options: brands,
          hint: 'Type brand…',
          error: errors['brand'],
          onTyped: (v) {
            row.model.clear(); // a different brand has different models
            onBrandTyped(v);
            onChanged();
          },
          onSelected: (v) {
            row.model.clear();
            onBrandTyped(v);
            onChanged();
          },
        ),
      ],
    );
  }

  Widget _modelField(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_hasShipment && !row.manualModel) {
      final lines = [
        for (final l in shipment?.lines ?? const <StockInLine>[])
          if (l.remaining > 0) l,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Model', required: true),
          DropdownButtonFormField<String>(
            key: ValueKey('line-${row.line?.lineId}'),
            initialValue: row.line?.lineId,
            isExpanded: true,
            hint: const Text('Select model…'),
            decoration: InputDecoration(errorText: errors['model']),
            items: [
              for (final l in lines)
                DropdownMenuItem(
                  value: l.lineId,
                  child: Text(
                    '${l.modelName} — ${l.remaining} remaining',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const DropdownMenuItem(
                value: _newModelKey,
                child: Text('+ New model on this shipment (not on the list)'),
              ),
            ],
            onChanged: _pickLine,
          ),
          if (row.line != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${row.line!.remaining} unit${row.line!.remaining == 1 ? '' : 's'} left on this shipment',
                style: t.bodySmall?.copyWith(color: AppColors.success),
              ),
            ),
        ],
      );
    }
    if (_hasShipment && row.manualModel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Model', required: true),
          TextField(
            controller: row.model,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'Type the model name…',
              errorText: errors['model'],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              children: [
                Text(
                  'Still tagged to this shipment · not on its manifest, so cost is typed, not landed · ',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                InkWell(
                  onTap: () {
                    row
                      ..manualModel = false
                      ..model.clear();
                    onChanged();
                  },
                  child: Text(
                    "choose from the shipment's list instead",
                    style: t.bodySmall?.copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Model', required: true),
        _autocomplete(
          controller: row.model,
          focus: row.modelFocus,
          options: [for (final m in models) m.name],
          hint: 'Type model…',
          error: errors['model'],
          subtitleFor: (name) {
            final m = models.where((x) => x.name == name).firstOrNull;
            return (m?.costPrice ?? 0) > 0
                ? formatCurrency(m!.costPrice!, code)
                : null;
          },
          onTyped: (_) => onChanged(),
          onSelected: (name) {
            final m = models.where((x) => x.name == name).firstOrNull;
            if (m != null) {
              _applyModelOption(m);
            } else {
              onChanged();
            }
          },
        ),
      ],
    );
  }

  Widget _autocomplete({
    required TextEditingController controller,
    required FocusNode focus,
    required List<String> options,
    required String hint,
    required ValueChanged<String> onTyped,
    required ValueChanged<String> onSelected,
    String? error,
    String? Function(String name)? subtitleFor,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        return [
          for (final o in options)
            if (q.isEmpty || o.toLowerCase().contains(q)) o,
        ];
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, c, f, submit) => TextField(
        controller: c,
        focusNode: f,
        onChanged: onTyped,
        decoration: InputDecoration(hintText: hint, errorText: error),
      ),
      optionsViewBuilder: (context, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in opts)
                  ListTile(
                    dense: true,
                    title: Text(o),
                    subtitle: subtitleFor?.call(o) == null
                        ? null
                        : Text(subtitleFor!(o)!),
                    onTap: () => onSel(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _breakdown(BuildContext context, StockInLine l) {
    final t = Theme.of(context).textTheme;
    Widget cell(String label, double v) => Expanded(
      child: Column(
        children: [
          Text(
            v.toStringAsFixed(2),
            style: t.titleSmall?.copyWith(
              color: v == 0 ? AppColors.textDisabled : AppColors.textPrimary,
            ),
          ),
          Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cost Breakdown — per unit', style: t.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              cell('Goods', l.goodsPerUnit),
              cell('Customs', l.customsPerUnit),
              cell('Freight', l.freightPerUnit),
              cell('Tax', l.taxPerUnit),
              cell('Other', l.otherPerUnit),
            ],
          ),
          if (l.stocked > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '${l.stocked} unit(s) already went out at a lower cost. Charges paid since then '
                'land on the ${l.remaining} still here, so this is higher than the shipment average.',
                style: t.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stockInDate(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Stock-In Date'),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.successSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 8, color: AppColors.success),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'AUTO · ${formatDate(DateTime.now())} · recorded on save',
                  style: t.bodySmall?.copyWith(color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                row.stockInDate == null
                    ? 'Set manual date (optional)'
                    : formatDate(row.stockInDate),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: row.stockInDate ?? DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  row.stockInDate = d;
                  onChanged();
                }
              },
            ),
            if (row.stockInDate != null)
              IconButton(
                tooltip: 'Clear manual date',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  row.stockInDate = null;
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}
