import 'package:flutter/material.dart';

import '../../../../../core/widgets/form_section.dart';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_search_field.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_states.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/widgets/currency_picker.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../domain/rules/add_stock_rules.dart';
import '../../domain/entities/product.dart';
import '../controllers/inventory_add_existing_controller.dart';
import '../widgets/location_picker.dart';

/// Add to Existing Inventory (React `/inventory/add-existing`): pick a
/// product, enter units / prices / serials, save.
class AddStockPage extends StatefulWidget {
  const AddStockPage({super.key});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final InventoryAddExistingController _c =
      Get.find<InventoryAddExistingController>();
  String _search = '';
  Product? _selected;

  final _qty = TextEditingController(text: '1');
  final _sell = TextEditingController();
  final _cost = TextEditingController();
  final List<TextEditingController> _serials = [TextEditingController()];
  final List<String> _cities = [''];

  @override
  void dispose() {
    _qty.dispose();
    _sell.dispose();
    _cost.dispose();
    for (final c in _serials) {
      c.dispose();
    }
    super.dispose();
  }

  int get _quantity => AddStockRules.parseQuantity(_qty.text);

  /// Selecting a product resets the whole form (as React).
  void _select(Product p) => setState(() {
    _selected = p;
    _qty.text = '1';
    _sell.text = _fmt(p.sellPrice);
    _cost.text = p.costPrice == null ? '' : _fmt(p.costPrice!);
    _resizeSerials(1, reset: true);
  });

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  void _resizeSerials(int n, {bool reset = false}) {
    if (reset) {
      for (final c in _serials) {
        c.clear();
      }
      _cities
        ..clear()
        ..addAll(List.filled(_serials.length, ''));
    }
    while (_serials.length < n) {
      _serials.add(TextEditingController());
      _cities.add('');
    }
    while (_serials.length > n) {
      _serials.removeLast().dispose();
      _cities.removeLast();
    }
  }

  void _onQtyChanged(String _) => setState(() => _resizeSerials(_quantity));

  void _save() {
    final p = _selected;
    if (p == null) return;
    final error = AddStockRules.validate(
      quantity: _quantity,
      serialInputs: [for (final c in _serials) c.text],
      existingOnProduct: p.serialNumbers,
    );
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    final serials = AddStockRules.filled([for (final c in _serials) c.text]);
    _c.addStock(
      productId: p.id,
      modelName: p.modelName,
      quantity: _quantity,
      serials: serials,
      // Only units that were given a location get an entry.
      serialCities: {
        for (var i = 0; i < _serials.length; i++)
          if (_serials[i].text.trim().isNotEmpty && _cities[i].isNotEmpty)
            _serials[i].text.trim(): _cities[i],
      },
      sellPrice: AddStockRules.parsePrice(_sell.text),
      costPrice: AddStockRules.parsePrice(_cost.text),
    );
  }

  void _onNotice(Notice n) {
    if (n.tag == 'add-stock' && !n.isError) {
      Get.offNamed(AppRoutes.inventoryView);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      onNotice: _onNotice,
      child: Obx(() {
        final list = _c.products.value;
        final code = Get.find<CurrencyProvider>().currencyCode.value;
        final busy = _c.busy.value;
        final loading =
            list.status == LoadStatus.idle ||
            list.status == LoadStatus.loading && list.items.isEmpty;

        Widget body;
        if (loading) {
          body = const SizedBox(
            height: 320,
            child: AppLoading(message: 'Loading products...'),
          );
        } else if (list.status == LoadStatus.failed) {
          body = SizedBox(
            height: 320,
            child: AppErrorState(
              message: 'Failed to load products',
              onRetry: _c.loadProducts,
            ),
          );
        } else {
          body = LayoutBuilder(
            builder: (context, c) {
              final picker = _Picker(
                products: list.items,
                search: _search,
                selectedId: _selected?.id,
                code: code,
                onSearch: (v) => setState(() => _search = v),
                onSelect: _select,
              );
              final form = _selected == null
                  ? const SizedBox(
                      height: 320,
                      child: AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Select a product to continue',
                      ),
                    )
                  : _form(context, _selected!, code, busy);
              if (c.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 340, child: picker),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: form,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  picker,
                  const SizedBox(height: AppSpacing.xl),
                  form,
                ],
              );
            },
          );
        }

        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            ScreenHeader(
              title: 'Add to Existing Inventory',
              subtitle: 'Select a product to add units, update prices, or add serial numbers',
              icon: Icons.add_box_outlined,
              iconColor: AppColors.success,
              onBack: () => Get.offNamed(AppRoutes.inventory),
              actions: const [CurrencyPicker()],
            ),
            const SizedBox(height: AppSpacing.lg),
            body,
          ],
        );
      }),
    );
  }

  Widget _form(BuildContext context, Product p, String code, bool busy) {
    final t = Theme.of(context).textTheme;
    final qty = _quantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.brandName} — ${p.modelName}', style: t.titleSmall),
              Text(
                'Current stock: ${p.stock} units',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Units to Add',
          required: true,
          controller: _qty,
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onQtyChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            SizedBox(
              width: 260,
              child: AppTextField(
                label: 'Retail Price',
                required: true,
                controller: _sell,
                enabled: !busy,
                prefixText: code,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            SizedBox(
              width: 260,
              child: AppTextField(
                label: 'Purchasing Cost',
                required: true,
                controller: _cost,
                enabled: !busy,
                prefixText: code,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            const Icon(Icons.tag, size: 18, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Text('Serial Numbers ($qty required)', style: t.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _serials.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UNIT ${i + 1}',
                    style: t.labelSmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _serials[i],
                    enabled: !busy,
                    decoration: InputDecoration(hintText: 'Serial #${i + 1}'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LocationPicker(
                    compact: true,
                    placeholder: 'Location (optional)',
                    value: _cities[i],
                    onChanged: (v) => setState(() => _cities[i] = v),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Add $qty Unit${qty > 1 ? 's' : ''} to Stock',
          icon: Icons.add,
          expand: true,
          isLoading: busy,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.products,
    required this.search,
    required this.selectedId,
    required this.code,
    required this.onSearch,
    required this.onSelect,
  });

  final List<Product> products;
  final String search;
  final String? selectedId;
  final String code;
  final ValueChanged<String> onSearch;
  final ValueChanged<Product> onSelect;

  @override
  Widget build(BuildContext context) {
    final q = search.trim().toLowerCase();
    final filtered = [
      for (final p in products)
        if (q.isEmpty ||
            p.brandName.toLowerCase().contains(q) ||
            p.modelName.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
          p,
    ];
    // Group by brand, keeping arrival order (newest first).
    final groups = <String, List<Product>>{};
    for (final p in filtered) {
      groups
          .putIfAbsent(p.brandName.isEmpty ? 'Unknown' : p.brandName, () => [])
          .add(p);
    }
    final t = Theme.of(context).textTheme;

    return FormCard(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchField(
              hint: 'Search brand, model, category...',
              onChanged: onSearch,
            ),
          ),
          const Divider(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: filtered.isEmpty
                ? const SizedBox(
                    height: 200,
                    child: AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products found',
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in groups.entries) ...[
                        Container(
                          color: AppColors.surfaceMuted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            e.key.toUpperCase(),
                            style: t.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        for (final p in e.value)
                          InkWell(
                            onTap: () => onSelect(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: p.id == selectedId
                                    ? AppColors.surfaceMuted
                                    : null,
                                border: Border(
                                  left: BorderSide(
                                    width: 3,
                                    color: p.id == selectedId
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.modelName, style: t.titleSmall),
                                  Text(
                                    'Stock: ${p.stock}'
                                    '${(p.location ?? '').isEmpty ? '' : ' · ${p.location}'}'
                                    ' · ${formatCurrency(p.sellPrice, code)}',
                                    style: t.bodySmall?.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
