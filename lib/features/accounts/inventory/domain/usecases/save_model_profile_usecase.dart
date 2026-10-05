import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/catalog.dart';
import '../repositories/catalog_repository.dart';

class SaveModelProfileParams extends Equatable {
  const SaveModelProfileParams({required this.brand, required this.profile});

  final String brand;
  final ModelOption profile;

  @override
  List<Object?> get props => [brand, profile];
}

/// One action: saveModelProfile.
class SaveModelProfileUseCase implements UseCase<Unit, SaveModelProfileParams> {
  SaveModelProfileUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SaveModelProfileParams params) =>
      _repository.saveModelProfile(params.brand, params.profile);
}
