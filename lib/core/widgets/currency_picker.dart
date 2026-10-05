import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../settings/currency_option.dart';
import '../settings/currency_provider.dart';

/// Compact system-currency selector (React `InventoryCurrencyDropdown`).
/// Symbol-only: it relabels amounts and never converts them.
class CurrencyPicker extends StatelessWidget {
  const CurrencyPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyProvider>();
    return Obx(() {
      final code = currency.currencyCode.value;
      final saving = currency.savingCurrency.value;
      return Tooltip(
        message: 'System currency (relabels amounts, no conversion)',
        child: DropdownButton<String>(
          value: kCurrencies.any((c) => c.code == code) ? code : null,
          isDense: true,
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.payments_outlined, size: 18),
          items: [
            for (final c in kCurrencies)
              DropdownMenuItem(value: c.code, child: Text(c.code)),
          ],
          onChanged: saving
              ? null
              : (v) => v == null ? null : currency.changeCurrency(v),
        ),
      );
    });
  }
}
