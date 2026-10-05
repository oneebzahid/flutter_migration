import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/supplier_payment.dart';
import '../repositories/payables_repository.dart';

class RecordSupplierPaymentUseCase
    implements UseCase<SupplierPayment, SupplierPaymentRequest> {
  RecordSupplierPaymentUseCase(this._repository);

  final PayablesRepository _repository;

  @override
  Future<Either<Failure, SupplierPayment>> call(
    SupplierPaymentRequest params,
  ) => _repository.recordPayment(params);
}
