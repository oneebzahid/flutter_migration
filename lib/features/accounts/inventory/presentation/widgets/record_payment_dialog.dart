import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/rules/payable_rules.dart';
import '../controllers/inventory_payables_controller.dart';

Future<void> showRecordPaymentDialog(BuildContext context, Product product) =>
    showDialog<void>(
      context: context,
      builder: (_) => _RecordPaymentDialog(product: product),
    );

/// "Pay brand — model": amount (defaults to what is owed), Cash / Bank,
/// bank account when Bank. One request id per dialog, so a double tap or a
/// retry can never pay twice; the button is disabled while saving.
class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({required this.product});
  final Product product;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _c = Get.find<InventoryPayablesController>();
  final _currency = Get.find<CurrencyProvider>();
  final String _requestId = 'pay-${DateTime.now().microsecondsSinceEpoch}';
  late final _amount = TextEditingController(
    text: widget.product.supplierOutstanding.toStringAsFixed(2),
  );
  PaymentChannel _channel = PaymentChannel.cash;
  String? _bankId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c.loadBanks();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _submit() async {
    final p = widget.product;
    if (_value <= 0) {
      setState(() => _error = 'Enter a valid payment amount');
      return;
    }
    final error = PayableRules.validate(
      product: p,
      amount: _value,
      channel: _channel,
      bankId: _bankId,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    final ok = await _c.pay(
      product: p,
      amount: _value,
      channel: _channel,
      bankId: _bankId,
      requestId: _requestId,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final t = Theme.of(context).textTheme;
    return Obx(() {
      final code = _currency.currencyCode.value;
      final busy = _c.busy.value;
      final banks = _c.banks.value;
      return AppDialog(
        title: 'Pay ${p.brandName} — ${p.modelName}',
        maxWidth: 420,
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: busy ? 'Saving…' : 'Confirm Payment',
            onPressed: busy ? null : _submit,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining: ${formatCurrency(p.supplierOutstanding, code)}',
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Amount ($code)',
              required: true,
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Paid Via',
              style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            SegmentedButton<PaymentChannel>(
              showSelectedIcon: false,
              segments: [
                for (final c in PaymentChannel.values)
                  ButtonSegment(value: c, label: Text(c.label)),
              ],
              selected: {_channel},
              onSelectionChanged: (s) => setState(() {
                _channel = s.first;
                _error = null;
              }),
            ),
            if (_channel == PaymentChannel.bank) ...[
              const SizedBox(height: AppSpacing.lg),
              Text.rich(
                TextSpan(
                  text: 'Bank Account',
                  style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
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
                initialValue: _bankId,
                isExpanded: true,
                hint: Text(
                  banks.isLoading
                      ? 'Loading banks…'
                      : '— Select bank account —',
                ),
                items: [
                  for (final b in banks.items)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        b.balance == null
                            ? b.name
                            : '${b.name} (${formatCurrency(b.balance!, code)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _bankId = v;
                  _error = null;
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'This records ${formatCurrency(_value, code)} paid from '
              '${_channel == PaymentChannel.cash ? 'cash' : 'the selected bank account'} '
              'and updates the payment status automatically.',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      );
    });
  }
}
