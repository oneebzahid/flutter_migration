import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/supplier_payment.dart';
import '../repositories/payables_repository.dart';

class GetBanksUseCase implements UseCase<List<BankAccount>, NoParams> {
  GetBanksUseCase(this._repository);

  final PayablesRepository _repository;

  @override
  Future<Either<Failure, List<BankAccount>>> call(NoParams params) =>
      _repository.fetchBanks();
}
