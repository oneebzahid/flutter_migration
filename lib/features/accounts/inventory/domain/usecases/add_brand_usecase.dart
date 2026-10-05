import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/catalog_repository.dart';

/// One action: addBrand.
class AddBrandUseCase implements UseCase<Unit, String> {
  AddBrandUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.addBrand(params);
}
