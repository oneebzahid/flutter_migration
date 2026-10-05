import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/catalog_repository.dart';

/// One action: generateTransactionId.
class GenerateTransactionIdUseCase implements UseCase<String, NoParams> {
  GenerateTransactionIdUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, String>> call(NoParams params) =>
      _repository.generateTransactionId();
}
