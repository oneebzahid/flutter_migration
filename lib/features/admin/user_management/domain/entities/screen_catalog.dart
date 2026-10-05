/// Permission screens, copied verbatim from `ALL_SCREEN_GROUPS` in the React
/// userService.ts. The strings are stored on user records, so they must not change.
class ScreenGroup {
  const ScreenGroup(this.title, this.screens);
  final String title;
  final List<String> screens;
}

const List<ScreenGroup> allScreenGroups = [
  ScreenGroup('Dashboard', ['Dashboard']),
  ScreenGroup('Transactions & Bills', [
    'Transaction List',
    'Add Transaction',
    'Transaction Edit',
    'Transaction Delete',
    'Pending Payments',
    'Bills List',
    'Create Bill',
    'Edit Bill',
    'Delete Bill',
  ]),
  ScreenGroup('Salary Management', [
    'Salary Dashboard',
    'Salary All List',
    'Salary Regular List',
    'Salary Advance List',
    'Create Regular Salary',
    'Create Advance Salary',
    'Salary Edit',
    'Salary Delete',
  ]),
  ScreenGroup('Invoices', [
    'Invoices List',
    'Create Invoice',
    'Edit Invoice',
    'Delete Invoice',
    'Invoice Reports',
    'Dummy Invoices',
    'Deleted Invoices',
  ]),
  ScreenGroup('Inventory', [
    'Inventory Dashboard',
    'Inventory View',
    'Inventory Receivable',
    'Deleted Inventory',
    'Inventory Add Returned',
    'Damaged Inventory',
    'Inventory Type Selection',
    'Inventory Costing Option',
    'Inventory Costing Details',
    'Inventory Multi Models',
    'Inventory Product Details',
    'Inventory Payment',
    'Inventory Add Existing',
    'Inventory Payables',
  ]),
  ScreenGroup('Product Transfer', [
    'Product Transfer List',
    'Create Product Transfer',
  ]),
  ScreenGroup('Purchases & Payables', ['Payable to Futuristic']),
  ScreenGroup('Employees', [
    'Employees List',
    'Create Employee',
    'Edit Employee',
    'Delete Employee',
  ]),
  ScreenGroup('Loans', [
    'Loans Dashboard',
    'All Loans List',
    'Loans Payable',
    'Loans Receivable',
    'Create Loan',
    'Create Payable Loan',
    'Create Receivable Loan',
    'Edit Loan',
    'Loan Payment',
  ]),
  ScreenGroup('Commission', [
    'Commission Slabs',
    'Commission Calculation',
    'Commission Reports',
  ]),
  ScreenGroup('Budgets', [
    'Budgets List',
    'Create Budget',
    'Edit Budget',
    'Delete Budget',
  ]),
  ScreenGroup('Finance Reports', [
    'Balance Sheet Report',
    'Bank Balance Report',
    'Bank Activity Report',
    'Expenses Report',
    'Fixed Bills Report',
    'Profit Loss Report',
    'Salaries Report',
    'Transaction History Report',
    'Loan History',
  ]),
  ScreenGroup('Sales Reports', [
    'Commission Report',
    'Sales Report',
    'Referral Report',
  ]),
  ScreenGroup('Inventory Reports', [
    'Inventory Report',
    'Product Transfer Report',
    'Inventory Charts',
  ]),
  ScreenGroup('Assets Management', ['Assets Management']),
];

/// Branch list hard-coded in the React UserManagement screen (BR-12 will
/// replace it with a configurable list). Stored lower-cased.
const List<String> kBranches = ['Saudia', 'Dubai', 'Chad', 'Sudan'];

String branchValue(String branch) => branch.toLowerCase();

/// Matches a stored branch (any casing) to a dropdown value, or null.
String? matchBranch(String stored) {
  final v = stored.toLowerCase();
  for (final b in kBranches) {
    if (b.toLowerCase() == v) return b.toLowerCase();
  }
  return null;
}

String branchLabel(String value) {
  if (value.isEmpty) return 'None';
  return value[0].toUpperCase() + value.substring(1);
}
