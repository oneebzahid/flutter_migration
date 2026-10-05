/// Route name constants. Add one per page - never use raw string literals
/// with `Get.toNamed` / `Get.offNamed` / `GetPage(name: ...)` elsewhere.
abstract class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  // Accounts
  static const String transactions = '/transactions';
  static const String inventory = '/inventory';
  static const String inventoryView = '/inventory/view';
  static const String inventoryReceivable = '/inventory/receivable';
  static const String inventoryCreate = '/inventory/create-new';
  static const String inventoryAddExisting = '/inventory/add-existing';
  static const String inventoryAddReturned = '/inventory/add-returned';
  static const String inventoryDamaged = '/inventory/damaged';
  static const String inventoryDeleted = '/inventory/deleted';
  static const String inventoryReport = '/inventory/report';
  static const String inventoryPayables = '/inventory/payables';
  static const String productTransfer = '/product-transfer';
  static const String productTransferNew = '/product-transfer/new';
  static const String purchasedOrders = '/purchased-orders';
  static const String invoices = '/invoices';
  static const String invoicesDummy = '/invoices/dummy';

  // Admin
  static const String userManagement = '/user-management';
}
