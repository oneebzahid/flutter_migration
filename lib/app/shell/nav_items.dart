import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/auth_user.dart';

class NavItem {
  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.path,
    this.screen,
    this.children = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final String? path;

  /// Permission key (React SCREEN_PERMISSIONS). Null = always visible.
  final String? screen;
  final List<NavItem> children;

  bool get hasChildren => children.isNotEmpty;
}

/// Mirrors `menuItems` in the React Sidebar, plus an explicit Dashboard entry
/// (React only reaches it via the logo).
const List<NavItem> appNavItems = [
  NavItem(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    path: '/dashboard',
    screen: Screens.dashboard,
  ),
  NavItem(
    id: 'transactions',
    label: 'Transactions',
    icon: Icons.swap_horiz,
    path: '/transactions',
    screen: Screens.transactions,
  ),
  NavItem(
    id: 'inventory',
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    path: '/inventory',
    screen: Screens.inventory,
  ),
  NavItem(
    id: 'purchased-orders',
    label: 'Purchased Orders',
    icon: Icons.local_shipping_outlined,
    path: '/purchased-orders',
    screen: Screens.inventory,
  ),
  NavItem(
    id: 'invoices',
    label: 'Invoices',
    icon: Icons.description_outlined,
    children: [
      NavItem(
        id: 'invoices-all',
        label: 'All Invoices',
        icon: Icons.list_alt,
        path: '/invoices',
        screen: Screens.invoices,
      ),
      NavItem(
        id: 'invoices-dummy',
        label: 'Fictitious Invoices',
        icon: Icons.note_add_outlined,
        path: '/invoices/dummy',
        screen: Screens.dummyInvoices,
      ),
    ],
  ),
  NavItem(
    id: 'user-management',
    label: 'User Management',
    icon: Icons.shield_outlined,
    path: '/user-management',
    screen: Screens.userManagement,
  ),
];

/// Items visible to [user]; parents with no visible children are dropped.
List<NavItem> visibleNavItems(AuthUser user) {
  final result = <NavItem>[];
  for (final item in appNavItems) {
    if (item.hasChildren) {
      final kids = item.children
          .where((c) => user.canAccess(c.screen))
          .toList();
      if (kids.isEmpty) continue;
      result.add(
        NavItem(
          id: item.id,
          label: item.label,
          icon: item.icon,
          children: kids,
        ),
      );
    } else if (user.canAccess(item.screen)) {
      result.add(item);
    }
  }
  return result;
}

/// The nav entry whose path is the longest prefix of [location].
NavItem? navItemFor(String location) {
  NavItem? best;
  for (final n in appNavItems.expand((n) => [n, ...n.children])) {
    final p = n.path;
    if (p != null && (location == p || location.startsWith('$p/'))) {
      if (best == null || p.length > best.path!.length) best = n;
    }
  }
  return best;
}

/// Sub-routes that React guards with their own screen permission (routes.tsx).
const Map<String, String> _routeScreens = {
  '/inventory/view': Screens.inventoryView,
  '/inventory/receivable': Screens.inventoryReceivable,
  '/inventory/report': Screens.inventoryReport,
  '/inventory/add-returned': Screens.inventoryAddReturned,
  '/inventory/damaged': Screens.damagedInventory,
  '/inventory/payables': Screens.inventoryPayables,
  '/inventory/create-new': Screens.inventoryTypeSelection,
  '/inventory/add-existing': Screens.inventoryAddExisting,
  '/inventory/deleted': Screens.deletedInventory,
  '/product-transfer': Screens.productTransferList,
  '/product-transfer/new': Screens.createProductTransfer,
};

/// Permission key required for [location], or null when unguarded. The most
/// specific route wins (so '/inventory/view' does not fall back to '/inventory').
String? requiredScreenFor(String location) {
  String? bestPath;
  String? screen;
  _routeScreens.forEach((p, s) {
    if ((location == p || location.startsWith('$p/')) &&
        (bestPath == null || p.length > bestPath!.length)) {
      bestPath = p;
      screen = s;
    }
  });
  return screen ?? navItemFor(location)?.screen;
}
