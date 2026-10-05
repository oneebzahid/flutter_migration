import 'package:get/get.dart';

/// App-wide read/write access to the system currency, so any feature can show
/// amounts without importing the settings feature's presentation layer.
/// `SettingsController` implements it and is registered in `InitialBindings`.
abstract interface class CurrencyProvider {
  RxString get currencyCode;
  RxBool get savingCurrency;

  /// Loads the saved currency (safe to call repeatedly).
  Future<void> loadCurrency();

  Future<void> changeCurrency(String code);
}
