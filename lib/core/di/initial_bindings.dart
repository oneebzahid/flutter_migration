import 'package:get/get.dart';

import '../../app/shell/shell_controller.dart';
import '../../features/accounts/inventory/data/datasources/inventory_datasource.dart';
import '../../features/accounts/inventory/data/datasources/mock_inventory_datasource.dart';
import '../../features/accounts/settings/data/datasources/mock_settings_datasource.dart';
import '../../features/accounts/settings/data/datasources/settings_datasource.dart';
import '../../features/accounts/settings/presentation/bindings/settings_binding.dart';
import '../../features/admin/user_management/data/datasources/mock_user_datasource.dart';
import '../../features/admin/user_management/data/datasources/user_datasource.dart';
import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/datasources/mock_auth_datasource.dart';
import '../../features/auth/presentation/bindings/auth_binding.dart';

/// App-wide singletons every feature can depend on: the signed-in session,
/// system settings (currency), the shell state and - while the backend is an
/// in-memory mock - the data sources (a mock must outlive any one route).
///
/// Pass your own data sources to swap them (tests use zero-latency mocks, the
/// real app will use Supabase ones). Feature controllers / use cases /
/// repositories belong in the feature's own `*_binding.dart`.
class InitialBindings extends Bindings {
  InitialBindings({
    this.authDataSource,
    this.userDataSource,
    this.settingsDataSource,
    this.inventoryDataSource,
  });

  final AuthDataSource? authDataSource;
  final UserDataSource? userDataSource;
  final SettingsDataSource? settingsDataSource;
  final InventoryDataSource? inventoryDataSource;

  @override
  void dependencies() {
    Get.put<AuthDataSource>(
      authDataSource ?? MockAuthDataSource(),
      permanent: true,
    );
    Get.put<UserDataSource>(
      userDataSource ?? MockUserDataSource(),
      permanent: true,
    );
    Get.put<SettingsDataSource>(
      settingsDataSource ?? MockSettingsDataSource(),
      permanent: true,
    );
    Get.put<InventoryDataSource>(
      inventoryDataSource ?? MockInventoryDataSource(),
      permanent: true,
    );

    AuthBinding().dependencies();
    SettingsBinding().dependencies();
    Get.put(ShellController(), permanent: true);
  }
}
