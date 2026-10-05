/// Supported system currencies (React `CURRENCIES` in finance/currencyUtils.ts).
class CurrencyOption {
  const CurrencyOption(this.code, this.label, this.decimals);
  final String code;
  final String label;
  final int decimals;
}

const List<CurrencyOption> kCurrencies = [
  CurrencyOption('PKR', 'Pakistani Rupee', 0),
  CurrencyOption('USD', 'US Dollar', 2),
  CurrencyOption('CAD', 'Canadian Dollar', 2),
  CurrencyOption('AED', 'UAE Dirham', 2),
  CurrencyOption('SAR', 'Saudi Riyal', 2),
  CurrencyOption('GBP', 'British Pound', 2),
  CurrencyOption('EUR', 'Euro', 2),
];
