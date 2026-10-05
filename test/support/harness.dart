import 'package:bullion_erp/core/di/initial_bindings.dart';
import 'package:bullion_erp/features/accounts/inventory/data/datasources/mock_inventory_datasource.dart';
import 'package:bullion_erp/features/accounts/settings/data/datasources/mock_settings_datasource.dart';
import 'package:bullion_erp/features/admin/user_management/data/datasources/mock_user_datasource.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:get/get.dart';

/// Test wiring for the GetX app.
///
/// Every test starts from a clean container ([resetGet]) and registers
/// zero-latency in-memory data sources through the same `InitialBindings` the
/// real app uses, so tests exercise the real controllers, use cases and
/// repositories - only the data source is a mock.
class Harness {
  Harness._({
    required this.auth,
    required this.users,
    required this.settings,
    required this.inventory,
  });

  final MockAuthDataSource auth;
  final MockUserDataSource users;
  final MockSettingsDataSource settings;
  final MockInventoryDataSource inventory;

  /// Fresh zero-latency data sources.
  factory Harness.fresh() => Harness._(
    auth: MockAuthDataSource(latency: Duration.zero),
    users: MockUserDataSource(latency: Duration.zero),
    settings: MockSettingsDataSource(latency: Duration.zero),
    inventory: MockInventoryDataSource(latency: Duration.zero),
  );

  InitialBindings get bindings => InitialBindings(
    authDataSource: auth,
    userDataSource: users,
    settingsDataSource: settings,
    inventoryDataSource: inventory,
  );

  /// Resets the container and registers the app-wide singletons (session,
  /// settings, data sources). Use in `setUp` for controller-level tests; the
  /// feature bindings (`InventoryBinding()`...) are then called by the test.
  static Harness install() {
    resetGet();
    final h = Harness.fresh();
    h.bindings.dependencies();
    return h;
  }
}

/// Clears every registered dependency (including permanent ones).
void resetGet() {
  Get.testMode = true;
  Get.reset();
}

/// Waits for [condition] by yielding to the event loop - it depends only on
/// the controller's own state, never on a wall-clock sleep, so it cannot be
/// flaky on a slow machine. A hard cap turns a stuck operation into a clear
/// failure instead of a hang.
Future<void> until(bool Function() condition, {int maxTurns = 5000}) async {
  for (var i = 0; i < maxTurns; i++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Condition not met after $maxTurns event-loop turns');
}
