import 'package:intl/intl.dart';

import '../settings/currency_option.dart';

/// Formats [amount] with the system currency code, e.g. `PKR 1,250,000`.
/// Symbol-only relabelling: the number is never converted (plan D5).
String formatCurrency(num amount, String code) {
  final decimals = kCurrencies
      .firstWhere(
        (c) => c.code == code,
        orElse: () => const CurrencyOption('', '', 2),
      )
      .decimals;
  final f = NumberFormat.decimalPatternDigits(
    locale: 'en_US',
    decimalDigits: decimals,
  );
  return '$code ${f.format(amount)}';
}

/// Plain grouped number (no currency), e.g. units or stock counts.
String formatCount(num value) =>
    NumberFormat.decimalPattern('en_US').format(value);
