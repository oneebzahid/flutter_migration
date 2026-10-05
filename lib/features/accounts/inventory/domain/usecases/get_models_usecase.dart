import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/catalog.dart';
import '../repositories/catalog_repository.dart';

/// One action: fetchModels.
class GetModelsUseCase implements UseCase<List<ModelOption>, String> {
  GetModelsUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, List<ModelOption>>> call(String params) =>
      _repository.fetchModels(params);
}
