import 'package:flutter/material.dart';

import '../../../../../core/widgets/form_section.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../controllers/inventory_return_controller.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/product.dart';
import '../../../../../core/theme/app_typography.dart';

/// Add Returned Inventory (React `/inventory/add-returned`).
///
/// Step 1 asks whether the item is damaged; step 2 finds the serial and
/// submits the return. A return reverses the linked invoice.
///
/// Deviations from React (both fix latent bugs): editing the serial text
/// clears a previous search result, so a result can never be submitted under
/// a different serial; and stock is not decremented for a sold serial that
/// is marked damaged.
class AddReturnedPage extends StatefulWidget {
  const AddReturnedPage({super.key});

  @override
  State<AddReturnedPage> createState() => _AddReturnedPageState();
}

class _AddReturnedPageState extends State<AddReturnedPage> {
  bool _chosen = false;
  bool _damaged = false;
  final _serial = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _serial.dispose();
    _note.dispose();
    super.dispose();
  }

  final InventoryReturnController _c = Get.find<InventoryReturnController>();

  void _choose(bool damaged) {
    setState(() {
      _chosen = true;
      _damaged = damaged;
    });
    _c.loadInvoices();
    if (damaged) _c.loadDamaged();
  }

  /// Back to step 1; keeps the damaged choice (React `backToChoose`).
  void _backToChoose() {
    _serial.clear();
    _note.clear();
    _c.reset();
    setState(() => _chosen = false);
  }

  /// Cancel: everything, including the damaged choice, is reset.
  void _cancel() {
    _serial.clear();
    _note.clear();
    _c.reset();
    setState(() {
      _chosen = false;
      _damaged = false;
    });
  }

  void _search({String? productId}) {
    final s = _serial.text.trim();
    if (s.isEmpty) {
      showAppSnackBar(
        context,
        'Enter a serial number to search',
        isError: true,
      );
      return;
    }
    _c.searchSerial(s, productId: productId);
  }

  void _onNotice(Notice n) {
    if (n.isError) return;
    if (n.tag == 'return-stock') {
      _cancel();
      Get.offNamed(AppRoutes.inventory);
    } else if (n.tag == 'return-damaged') {
      // Stay on the damaged flow for the next item.
      _serial.clear();
      _note.clear();
      _c.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      onNotice: _onNotice,
      child: Obx(() {
        final code = Get.find<CurrencyProvider>().currencyCode.value;
        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            ScreenHeader(
              title: 'Add Returned Inventory',
              subtitle: 'Choose how this return should be processed',
              icon: Icons.undo,
              iconColor: AppColors.warning,
              onBack: _chosen
                  ? _backToChoose
                  : () => Get.offNamed(AppRoutes.inventory),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _chosen ? 560 : 900),
                child: _chosen
                    ? _stepSearch(context, code)
                    : _stepChoose(context),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ───────── Step 1 ─────────

  Widget _stepChoose(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget card({
      required bool damaged,
      required IconData icon,
      required Color color,
      required Color tint,
      required String title,
      required String sub,
      required String body,
      bool fill = false,
    }) => InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => _choose(damaged),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium),
                      Text(
                        sub,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            (fill
                ? Expanded(
                    child: Text(
                      body,
                      style: t.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Text(
                    body,
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select', style: t.labelLarge?.copyWith(color: color)),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.arrow_forward, size: 16, color: color),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Is the returned product damaged?', style: t.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 640;
            final notDamaged = card(
              fill: wide,
              damaged: false,
              icon: Icons.inventory_2_outlined,
              color: AppColors.success,
              tint: AppColors.successSoft,
              title: 'Not Damaged',
              sub: 'Back to stock',
              body:
                  'Returns to stock under the same serial number with a fresh '
                  'stock-in date. Linked invoice moves to Deleted Invoices.',
            );
            final damaged = card(
              fill: wide,
              damaged: true,
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              tint: AppColors.errorSoft,
              title: 'Damaged',
              sub: 'Move to Damaged Inventory',
              body:
                  "Removed from live stock entirely and archived. Won't appear in "
                  'inventory list/report. Linked invoice also moves to Deleted Invoices.',
            );
            if (c.maxWidth >= 640) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: notDamaged),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: damaged),
                  ],
                ),
              );
            }
            return Column(
              children: [
                notDamaged,
                const SizedBox(height: AppSpacing.lg),
                damaged,
              ],
            );
          },
        ),
      ],
    );
  }

  // ───────── Step 2 ─────────

  Widget _stepSearch(BuildContext context, String code) {
    final t = Theme.of(context).textTheme;
    final searchState = _c.search.value;
    final busy = _c.submitting.value;
    final lookup = _c.lookup.value;
    final accent = _damaged ? AppColors.error : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Condition strip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _damaged ? AppColors.errorSoft : AppColors.successSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Condition: ${_damaged ? 'Damaged' : 'Not Damaged'}',
                  style: t.labelLarge?.copyWith(color: accent),
                ),
              ),
              TextButton(onPressed: _backToChoose, child: const Text('Change')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Search
        FormCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Serial Number',
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _serial,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Scan or type serial number',
                        ),
                        // A stale result must never be submitted under new text.
                        onChanged: (_) {
                          if (_c.search.value != ReturnSearch.idle) {
                            _c.reset();
                          }
                        },
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton(
                      label: 'Search',
                      icon: Icons.search,
                      isLoading: searchState == ReturnSearch.searching,
                      onPressed: () => _search(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (searchState == ReturnSearch.notFound) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: AppColors.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No inventory item found with that serial number.',
                    style: t.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (lookup != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _foundCard(context, lookup, code, busy),
        ],
        const SizedBox(height: AppSpacing.lg),
        _recentInvoices(context, _c.invoices.value, code),
        if (_damaged) ...[
          const SizedBox(height: AppSpacing.lg),
          _recentDamaged(context, _c.damaged.value),
        ],
      ],
    );
  }

  Widget _foundCard(
    BuildContext context,
    ReturnLookup l,
    String code,
    bool busy,
  ) {
    final t = Theme.of(context).textTheme;
    final p = l.product;
    final inv = l.invoice;
    final credit = p.ownershipType == OwnershipType.credit;
    return FormCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Item found',
                  style: t.titleSmall?.copyWith(color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.brandName} — ${p.modelName}', style: t.titleSmall),
                  Text(
                    'Location: ${(p.location ?? '').isEmpty ? '—' : p.location} · '
                    'Ownership: ${p.ownershipType?.label ?? '—'}',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (inv != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Invoice: ${inv.invoiceNumber}',
                      style: t.labelLarge,
                    ),
                    Text(
                      '${inv.customerName} · ${formatDate(inv.date)} · ${formatCurrency(inv.totalAmount, code)}',
                      style: t.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This invoice will move to Deleted Invoices when you submit.',
                      style: t.bodySmall?.copyWith(color: AppColors.info),
                    ),
                  ],
                ),
              ),
            ],
            if (_damaged) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Damage Note (optional)',
                style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe the damage…',
                ),
              ),
            ],
            if (!_damaged && credit) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This item is currently on supplier credit. Returning it will mark the product as Owned.',
                        style: t.bodySmall?.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
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
                  onPressed: busy ? null : _cancel,
                ),
                AppButton(
                  label: busy
                      ? 'Processing…'
                      : (_damaged
                            ? 'Move to Damaged Inventory'
                            : 'Return to Stock'),
                  variant: _damaged
                      ? AppButtonVariant.danger
                      : AppButtonVariant.success,
                  isLoading: busy,
                  onPressed: busy
                      ? null
                      : () => _c.submit(
                          found: l,
                          isDamaged: _damaged,
                          reason: _note.text,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentInvoices(
    BuildContext context,
    Loadable<InvoiceRef> list,
    String code,
  ) {
    final t = Theme.of(context).textTheme;
    return FormCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECENT INVOICES',
              style: t.labelSmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            if (list.items.isEmpty)
              Text(
                'No invoices found.',
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final inv = list.items[i];
                    final refs = inv.serialRefs;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.md,
                            children: [
                              Text(inv.invoiceNumber, style: t.titleSmall),
                              Text(inv.customerName, style: t.bodyMedium),
                              Text(
                                formatDate(inv.date),
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                formatCurrency(inv.totalAmount, code),
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (refs.isEmpty)
                            Text(
                              'No serial numbers recorded on this invoice.',
                              style: t.bodySmall?.copyWith(
                                color: AppColors.textDisabled,
                              ),
                            )
                          else
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final (pid, serial) in refs)
                                  Tooltip(
                                    message: 'Click to select this serial and process the return',
                                    child: ActionChip(
                                      backgroundColor: AppColors.sidebar,
                                      side: BorderSide.none,
                                      label: Text(
                                        '$serial · Select',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: AppTypography.monoFamily,
                                          fontFamilyFallback:
                                              AppTypography.monoFallback,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: () {
                                        _serial.text = serial;
                                        _search(productId: pid);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recentDamaged(BuildContext context, Loadable<DamagedRecord> list) {
    final t = Theme.of(context).textTheme;
    final items = list.items.take(8).toList();
    final fmt = DateFormat.yMd('en_US');
    return FormCard(
      highlight: AppColors.error.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAMAGED INVENTORY (RECENT)',
              style: t.labelSmall?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              Text(
                'No damaged records yet.',
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final d in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs + 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${d.brandName} ${d.modelName}',
                                style: t.bodyMedium,
                              ),
                            ),
                            Text(
                              d.serialNumber,
                              style: const TextStyle(
                                fontFamily: AppTypography.monoFamily,
                                fontFamilyFallback: AppTypography.monoFallback,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              fmt.format(d.damagedAt),
                              style: t.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
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
}
