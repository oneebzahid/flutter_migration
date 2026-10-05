import '../entities/product.dart';
import '../entities/supplier_payment.dart';
import 'inventory_logic.dart';

/// Which products are payable and how totals are shown (React
/// `fetchPayableProducts` + the Payables view model). Pure Dart.
abstract final class PayableRules {
  /// Credit stock that is not fully cleared, or still has a balance.
  static bool isPayable(Product p) =>
      p.ownershipType == OwnershipType.credit &&
      (p.supplierPaymentStatus != SupplierPaymentStatus.cleared ||
          p.supplierOutstanding > 0);

  /// Sold out (no units on hand): the amount is due now.
  static bool isSoldOut(Product p) => p.stock == 0;

  /// Search by brand or model (case-insensitive substring), as React.
  static bool matches(Product p, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.brandName.toLowerCase().contains(q) ||
        p.modelName.toLowerCase().contains(q);
  }

  /// Due now = outstanding on sold-out items; the rest is "still in stock".
  /// React ignores the search filter for these totals.
  static ({double dueNow, double stillInStock}) totals(List<Product> all) {
    var due = 0.0;
    var future = 0.0;
    for (final p in all) {
      if (isSoldOut(p)) {
        due += p.supplierOutstanding;
      } else {
        future += p.supplierOutstanding;
      }
    }
    return (dueNow: due, stillInStock: future);
  }

  /// Payment form check; the same guards as [SupplierPaymentRules] plus the
  /// bank requirement. Null = valid.
  static String? validate({
    required Product product,
    required double amount,
    required PaymentChannel channel,
    required String? bankId,
  }) {
    final error = SupplierPaymentRules.validate(
      cost: product.supplierCost,
      paid: product.supplierPaidAmount ?? 0,
      amount: amount,
    );
    if (error != null) return error;
    if (channel == PaymentChannel.bank && (bankId == null || bankId.isEmpty)) {
      return 'Please select a bank account';
    }
    return null;
  }
}
