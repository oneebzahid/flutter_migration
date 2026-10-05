import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/router/module_placeholder_page.dart';
import '../../app/shell/app_shell.dart';
import '../../features/accounts/dashboard/presentation/dashboard_page.dart';
import '../../features/accounts/inventory/domain/entities/product.dart';
import '../../features/accounts/inventory/presentation/bindings/inventory_binding.dart';
import '../../features/accounts/inventory/presentation/pages/create_inventory_page.dart';
import '../../features/accounts/inventory/presentation/pages/damaged_inventory_page.dart';
import '../../features/accounts/inventory/presentation/pages/deleted_inventory_page.dart';
import '../../features/accounts/inventory/presentation/pages/inventory_add_existing_page.dart';
import '../../features/accounts/inventory/presentation/pages/inventory_dashboard_page.dart';
import '../../features/accounts/inventory/presentation/pages/inventory_list_page.dart';
import '../../features/accounts/inventory/presentation/pages/inventory_payables_page.dart';
import '../../features/accounts/inventory/presentation/pages/inventory_return_page.dart';
import '../../features/accounts/inventory/presentation/pages/product_transfer_create_page.dart';
import '../../features/accounts/inventory/presentation/pages/product_transfer_page.dart';
import '../../features/admin/user_management/presentation/bindings/user_management_binding.dart';
import '../../features/admin/user_management/presentation/pages/user_management_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../widgets/app_states.dart';
import 'app_routes.dart';
import 'auth_guard.dart';

/// GetX route table.
///
/// Every feature registers its page(s) here with its own [Bindings] class, so
/// controllers / use cases / repositories are only constructed when that route
/// is first visited (`Get.lazyPut` inside the binding).
///
/// Signed-in pages are wrapped in the app frame ([AppShell]: sidebar + top
/// bar) and guarded by [AuthGuard]; the shell's own state lives in a
/// controller, so it survives navigation.
class AppPages {
  static const initial = AppRoutes.dashboard;

  static GetPage<dynamic> _shell(
    String name,
    Widget Function() page, {
    Bindings? binding,
  }) => GetPage(
    name: name,
    page: () => AppShell(location: name, child: page()),
    binding: binding,
    middlewares: [AuthGuard()],
    transition: Transition.noTransition,
  );

  static GetPage<dynamic> _placeholder(
    String name,
    String title,
    String note,
  ) => _shell(name, () => ModulePlaceholderPage(title: title, note: note));

  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      middlewares: [AuthGuard()],
      transition: Transition.noTransition,
    ),
    _shell(AppRoutes.dashboard, () => const DashboardPage()),
    _placeholder(
      AppRoutes.transactions,
      'Transactions',
      'Ledger list, create/edit, pending approvals.',
    ),

    // ── Accounts: inventory (one binding for the whole feature) ──
    _shell(
      AppRoutes.inventory,
      () => const InventoryDashboardPage(),
      binding: InventoryBinding(),
    ),
    // React renders the same in-stock list for both of these routes.
    _shell(
      AppRoutes.inventoryView,
      () => const InventoryListPage(type: InventoryType.inStock),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryReceivable,
      () => const InventoryListPage(type: InventoryType.inStock),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryCreate,
      () => const AddInventoryPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryAddExisting,
      () => const AddStockPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryAddReturned,
      () => const AddReturnedPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryDamaged,
      () => const DamagedInventoryPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryDeleted,
      () => const DeletedInventoryPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryReport,
      () => const InventoryDashboardPage(reportMode: true),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.inventoryPayables,
      () => const InventoryPayablesPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.productTransfer,
      () => const ProductTransferPage(),
      binding: InventoryBinding(),
    ),
    _shell(
      AppRoutes.productTransferNew,
      () => const ProductTransferCreatePage(),
      binding: InventoryBinding(),
    ),
    _placeholder(
      AppRoutes.purchasedOrders,
      'Purchased Orders',
      'Shipments, costing and goods received.',
    ),
    _placeholder(
      AppRoutes.invoices,
      'All Invoices',
      'Invoice list, create/edit, reports, deleted.',
    ),
    _placeholder(
      AppRoutes.invoicesDummy,
      'Fictitious Invoices',
      'Fictitious invoice list and form.',
    ),

    // ── Admin ──
    _shell(
      AppRoutes.userManagement,
      () => const UserManagementPage(),
      binding: UserManagementBinding(),
    ),
  ];

  static final unknownRoute = GetPage<dynamic>(
    name: '/not-found',
    page: () => const Scaffold(
      body: AppErrorState(
        title: 'Page not found',
        message: 'This page does not exist.',
      ),
    ),
  );
}
