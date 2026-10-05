import 'package:equatable/equatable.dart';

enum UserRole { superAdmin, user }

/// Screen names are the same strings the React app stores in
/// `users/{uid}.permissions` (see SCREEN_PERMISSIONS in Sidebar.tsx).
abstract final class Screens {
  static const dashboard = 'Dashboard';
  static const inventory = 'Inventory Dashboard';
  static const inventoryView = 'Inventory View';
  static const inventoryReceivable = 'Inventory Receivable';
  static const inventoryReport = 'Inventory Report';
  static const inventoryAddReturned = 'Inventory Add Returned';
  static const inventoryTypeSelection = 'Inventory Type Selection';
  static const inventoryAddExisting = 'Inventory Add Existing';
  static const damagedInventory = 'Damaged Inventory';
  static const inventoryPayables = 'Inventory Payables';
  static const deletedInventory = 'Deleted Inventory';
  static const productTransferList = 'Product Transfer List';
  static const createProductTransfer = 'Create Product Transfer';
  static const invoices = 'Invoices List';
  static const dummyInvoices = 'Dummy Invoices';
  static const transactions = 'Transaction List';
  static const employees = 'Employees List';
  static const payableFuturistic = 'Payable to Futuristic';
  static const userManagement = 'User Management';
}

class AuthUser extends Equatable {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.role,
    this.permissions = const [],
    this.branch = '',
  });

  final String uid;
  final String email;
  final UserRole role;
  final List<String> permissions;
  final String branch;

  bool get isSuperAdmin => role == UserRole.superAdmin;

  /// Same rule as the React sidebar: super admins see everything, others need
  /// the screen in their permission list. [Screens.userManagement] is admin-only.
  bool canAccess(String? screen) {
    if (isSuperAdmin) return true;
    if (screen == Screens.userManagement) return false;
    if (screen == null) return true;
    return permissions.contains(screen);
  }

  @override
  List<Object?> get props => [uid, email, role, permissions, branch];
}
