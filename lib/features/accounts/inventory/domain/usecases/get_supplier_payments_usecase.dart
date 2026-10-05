import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/supplier_payment.dart';
import '../repositories/payables_repository.dart';

class GetSupplierPaymentsUseCase
    implements UseCase<List<SupplierPayment>, String> {
  GetSupplierPaymentsUseCase(this._repository);

  final PayablesRepository _repository;

  @override
  Future<Either<Failure, List<SupplierPayment>>> call(String params) =>
      _repository.fetchPayments(params);
}
