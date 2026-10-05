import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../data/datasources/settings_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/get_currency_usecase.dart';
import '../../domain/usecases/set_currency_usecase.dart';
import '../controllers/settings_controller.dart';

/// Wires the system settings. Called once from `InitialBindings` because the
/// currency is needed by every feature; exposes the controller as the
/// [CurrencyProvider].
///
/// Expects a [SettingsDataSource] to be registered already (mock or real).
class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SettingsRepository>(
      SettingsRepositoryImpl(Get.find<SettingsDataSource>()),
      permanent: true,
    );
    final controller = Get.put(
      SettingsController(
        GetCurrencyUseCase(Get.find<SettingsRepository>()),
        SetCurrencyUseCase(Get.find<SettingsRepository>()),
      ),
      permanent: true,
    );
    Get.put<CurrencyProvider>(controller, permanent: true);
  }
}
