import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/catalog_repository.dart';

class AddModelParams extends Equatable {
  const AddModelParams({required this.brand, required this.model});

  final String brand;
  final String model;

  @override
  List<Object?> get props => [brand, model];
}

/// One action: addModel.
class AddModelUseCase implements UseCase<Unit, AddModelParams> {
  AddModelUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(AddModelParams params) =>
      _repository.addModel(params.brand, params.model);
}
