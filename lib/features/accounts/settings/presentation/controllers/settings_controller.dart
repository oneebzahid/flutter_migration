import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/usecases/get_currency_usecase.dart';
import '../../domain/usecases/set_currency_usecase.dart';

/// System settings (currency). Registered once in `InitialBindings`
/// (permanent) and exposed to every feature as a [CurrencyProvider].
class SettingsController extends GetxController
    with NoticeMixin
    implements CurrencyProvider {
  SettingsController(this._getCurrency, this._setCurrency);

  final GetCurrencyUseCase _getCurrency;
  final SetCurrencyUseCase _setCurrency;

  @override
  final RxString currencyCode = 'PKR'.obs;

  @override
  final RxBool savingCurrency = false.obs;

  final RxBool loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCurrency();
  }

  @override
  Future<void> loadCurrency() async {
    loading.value = true;
    final result = await _getCurrency(const NoParams());
    // Falls back to PKR (the default) when loading fails.
    currencyCode.value = result.getOrElse(() => 'PKR');
    loading.value = false;
  }

  @override
  Future<void> changeCurrency(String code) async {
    if (savingCurrency.value) return;
    savingCurrency.value = true;
    final result = await _setCurrency(code);
    savingCurrency.value = false;
    result.fold((f) => notify(f.message, isError: true), (_) {
      currencyCode.value = code;
      notify('System currency set to $code');
    });
  }
}
