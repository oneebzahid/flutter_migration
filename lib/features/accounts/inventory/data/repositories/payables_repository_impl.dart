import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/repositories/payables_repository.dart';
import '../datasources/inventory_datasource.dart';

/// Bridges [InventoryDataSource] (throws) to [PayablesRepository] (`Either`).
class PayablesRepositoryImpl implements PayablesRepository {
  PayablesRepositoryImpl(this._source);

  final InventoryDataSource _source;

  @override
  Future<Either<Failure, List<Product>>> fetchPayables() => guardCall(
    _source.fetchPayables,
    fallback: 'Failed to load inventory payables',
  );

  @override
  Future<Either<Failure, List<BankAccount>>> fetchBanks() =>
      guardCall(_source.fetchBanks);

  @override
  Future<Either<Failure, SupplierPayment>> recordPayment(
    SupplierPaymentRequest request,
  ) => guardCall(
    () => _source.recordSupplierPayment(request),
    fallback: 'Failed to record payment',
  );

  @override
  Future<Either<Failure, List<SupplierPayment>>> fetchPayments(
    String productId,
  ) => guardCall(() => _source.fetchSupplierPayments(productId));
}
