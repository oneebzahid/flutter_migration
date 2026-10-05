import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/product.dart';
import '../entities/supplier_payment.dart';

/// Supplier-credit payables. Recording a payment is ONE atomic operation
/// (validation, paid total, status and the payment record together).
abstract interface class PayablesRepository {
  /// Credit products that still owe the supplier (see `PayableRules`).
  Future<Either<Failure, List<Product>>> fetchPayables();

  /// Banks a payment can be made from.
  Future<Either<Failure, List<BankAccount>>> fetchBanks();

  /// Pays [request.amount] towards a product. Fails with a
  /// `ValidationFailure` for overpayment, a zero amount or a missing cost.
  /// A repeated [SupplierPaymentRequest.requestId] returns the first result.
  Future<Either<Failure, SupplierPayment>> recordPayment(
    SupplierPaymentRequest request,
  );

  /// Payment history of one product, newest first.
  Future<Either<Failure, List<SupplierPayment>>> fetchPayments(
    String productId,
  );
}
