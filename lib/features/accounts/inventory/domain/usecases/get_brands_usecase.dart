import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/catalog_repository.dart';

/// One action: fetchBrands.
class GetBrandsUseCase implements UseCase<List<String>, NoParams> {
  GetBrandsUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, List<String>>> call(NoParams params) =>
      _repository.fetchBrands();
}
