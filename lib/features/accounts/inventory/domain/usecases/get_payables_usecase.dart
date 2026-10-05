import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/payables_repository.dart';

class GetPayablesUseCase implements UseCase<List<Product>, NoParams> {
  GetPayablesUseCase(this._repository);

  final PayablesRepository _repository;

  @override
  Future<Either<Failure, List<Product>>> call(NoParams params) =>
      _repository.fetchPayables();
}
