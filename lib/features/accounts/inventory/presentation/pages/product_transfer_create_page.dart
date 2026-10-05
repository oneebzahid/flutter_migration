import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_states.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/form_section.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_transfer.dart';
import '../../domain/rules/transfer_rules.dart';
import '../controllers/product_transfer_controller.dart';
import '../widgets/location_picker.dart';

/// New transfer form (React `/product-transfer/new`). Creates one Pending
/// transfer per product; dispatching and receiving happen from the list.
class ProductTransferCreatePage extends StatefulWidget {
  const ProductTransferCreatePage({super.key});

  @override
  State<ProductTransferCreatePage> createState() =>
      _ProductTransferCreatePageState();
}

class _ProductTransferCreatePageState extends State<ProductTransferCreatePage> {
  late DateTime _date = DateTime.now();
  final ProductTransferController _c = Get.find<ProductTransferController>();
  late final _by = TextEditingController(
    text: Get.find<SessionProvider>().currentUser?.email,
  );
  final _cost = TextEditingController();
  String _from = '';
  String _to = '';
  final Map<String, Set<String>> _picked = {};
  String? _error;

  /// One id per form: resubmitting the same form can never create twice.
  final String _requestId = 'req-${DateTime.now().microsecondsSinceEpoch}';

  bool get _dirty =>
      _from.isNotEmpty ||
      _to.isNotEmpty ||
      _picked.isNotEmpty ||
      _cost.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _c.loadProducts();
  }

  @override
  void dispose() {
    _by.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_dirty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Discard this transfer?',
        message: 'Your selections have not been saved.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    Get.offNamed(AppRoutes.productTransfer);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(
        () =>
            _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute),
      );
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (t != null) {
      setState(
        () => _date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          t.hour,
          t.minute,
        ),
      );
    }
  }

  List<TransferLine> _lines(List<Product> products) => [
    for (final p in products)
      if ((_picked[p.id] ?? {}).isNotEmpty)
        TransferLine(
          productId: p.id,
          serials: [
            for (final s in p.serialNumbers)
              if (_picked[p.id]!.contains(s)) s,
          ],
          unitValue: p.costPrice ?? 0,
        ),
  ];

  void _save(List<Product> products) {
    final cost = double.tryParse(_cost.text.trim()) ?? 0;
    final lines = _lines(products);
    final error = TransferRules.validate(
      transferredBy: _by.text,
      from: _from,
      to: _to,
      lines: lines,
      shipmentCost: cost,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    _c.createTransfers(
      TransferRequest(
        date: _date,
        transferredBy: _by.text.trim(),
        from: _from,
        to: _to,
        lines: lines,
        shipmentCost: cost,
        requestId: _requestId,
      ),
    );
  }

  void _onNotice(Notice n) {
    if (n.tag == 'create' && !n.isError) {
      _picked.clear();
      _from = '';
      _to = '';
      _cost.clear();
      Get.offNamed(AppRoutes.productTransfer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: NoticeListener(
        notice: _c.notice,
        onNotice: _onNotice,
        child: Obx(() {
          final code = Get.find<CurrencyProvider>().currencyCode.value;
          final busy = _c.busy.value;
          final inv = _c.products.value;
          final reserved = _c.reserved.toSet();

          // Products with at least one serial that can leave the source.
          final available = <Product, List<String>>{};
          if (_from.isNotEmpty) {
            for (final p in inv.items) {
              if (p.receivableStatus == ReceivableStatus.pending) continue;
              final ok = [
                for (final s in p.serialNumbers)
                  if (TransferRules.eligible(
                    serial: s,
                    product: p,
                    from: _from,
                    reservedSerials: reserved,
                  ))
                    s,
              ];
              if (ok.isNotEmpty) available[p] = ok;
            }
          }
          final products = available.keys.toList();
          final lines = _lines(products);
          final totalUnits = lines.fold<int>(0, (s, l) => s + l.serials.length);
          final cost = double.tryParse(_cost.text.trim()) ?? 0;
          final shares = TransferRules.splitFreight(cost, lines);

          return ListView(
            padding: AppSpacing.pagePadding,
            children: [
              ScreenHeader(
                title: 'New Transfer',
                subtitle: 'Choose a route and the serials to move',
                icon: Icons.swap_horiz,
                iconColor: AppColors.info,
                onBack: _leave,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormSection(
                        title: 'Transfer details',
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth >= 640 ? 2 : 1;
                            final w =
                                (c.maxWidth - AppSpacing.lg * (cols - 1)) /
                                cols;
                            return Wrap(
                              spacing: AppSpacing.lg,
                              runSpacing: AppSpacing.lg,
                              children: [
                                SizedBox(
                                  width: w,
                                  child: _DateTimeField(
                                    value: _date,
                                    onDate: _pickDate,
                                    onTime: _pickTime,
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: AppTextField(
                                    label: 'Transferred by',
                                    required: true,
                                    controller: _by,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: LocationPicker(
                                    label: 'From (source)',
                                    required: true,
                                    value: _from,
                                    onChanged: (v) => setState(() {
                                      _from = v;
                                      _picked
                                          .clear(); // serials depend on source
                                    }),
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: LocationPicker(
                                    label: 'To (destination)',
                                    required: true,
                                    value: _to,
                                    onChanged: (v) => setState(() => _to = v),
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: AppTextField(
                                    label: 'Shipment cost',
                                    prefixText: code,
                                    helperText: 'Optional · split across products by value',
                                    controller: _cost,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FormSection(
                        title: 'Items to transfer',
                        subtitle: _from.isEmpty
                            ? 'Select the source location first'
                            : '$totalUnits unit(s) selected',
                        child: _items(inv, available, products),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (lines.isNotEmpty && cost > 0)
                        FormSection(
                          title: 'Shipment cost split',
                          subtitle: 'By product value; adds up to the total',
                          child: Column(
                            children: [
                              for (var i = 0; i < lines.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          products
                                              .firstWhere(
                                                (p) =>
                                                    p.id == lines[i].productId,
                                              )
                                              .let(
                                                (p) =>
                                                    '${p.brandName} ${p.modelName}',
                                              ),
                                        ),
                                      ),
                                      Text(formatCurrency(shares[i], code)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppButton(
                            label: 'Cancel',
                            variant: AppButtonVariant.secondary,
                            onPressed: busy ? null : _leave,
                          ),
                          AppButton(
                            label: busy ? 'Saving…' : 'Save transfer',
                            icon: Icons.check,
                            onPressed: busy ? null : () => _save(products),
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
      ),
    );
  }

  Widget _items(
    Loadable<Product> inv,
    Map<Product, List<String>> available,
    List<Product> products,
  ) {
    if (_from.isEmpty) {
      return const Text(
        'Pick a source location to see what can be moved.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }
    if (inv.status == LoadStatus.idle || inv.status == LoadStatus.loading) {
      return const AppLoading(message: 'Loading stock…');
    }
    if (available.isEmpty) {
      return Text(
        'No available units at $_from (sold, damaged, in transit or already '
        'on another transfer).',
        style: const TextStyle(color: AppColors.textMuted),
      );
    }
    final byBrand = <String, List<Product>>{};
    for (final p in products) {
      byBrand.putIfAbsent(p.brandName, () => []).add(p);
    }
    final brands = byBrand.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in brands) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              b.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ),
          for (final p in byBrand[b]!)
            _ProductPicker(
              product: p,
              serials: available[p]!,
              selected: _picked[p.id] ?? {},
              onChanged: (set) => setState(() {
                if (set.isEmpty) {
                  _picked.remove(p.id);
                } else {
                  _picked[p.id] = set;
                }
                _error = null;
              }),
            ),
        ],
      ],
    );
  }
}

extension on Product {
  T let<T>(T Function(Product p) f) => f(this);
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.product,
    required this.serials,
    required this.selected,
    required this.onChanged,
  });

  final Product product;
  final List<String> serials;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final all = selected.length == serials.length;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: selected.isNotEmpty,
        title: Text(product.modelName, style: t.titleSmall),
        subtitle: Text(
          '${selected.length} of ${serials.length} selected',
          style: t.bodySmall?.copyWith(
            color: selected.isEmpty ? AppColors.textMuted : AppColors.info,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => onChanged(all ? {} : {...serials}),
              child: Text(all ? 'Clear all' : 'Select all'),
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in serials)
                FilterChip(
                  label: Text(s),
                  selected: selected.contains(s),
                  onSelected: (on) => onChanged(
                    on ? {...selected, s} : ({...selected}..remove(s)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.value,
    required this.onDate,
    required this.onTime,
  });
  final DateTime value;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget box(IconData icon, String text, VoidCallback onTap, String tip) =>
        Expanded(
          child: Tooltip(
            message: tip,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: onTap,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderStrong),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(text, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    String two(int n) => n.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Date & time',
          style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          children: [
            box(
              Icons.calendar_today_outlined,
              formatDate(value),
              onDate,
              'Change date',
            ),
            const SizedBox(width: AppSpacing.sm),
            box(
              Icons.schedule,
              '${two(value.hour)}:${two(value.minute)}',
              onTime,
              'Change time',
            ),
          ],
        ),
      ],
    );
  }
}
