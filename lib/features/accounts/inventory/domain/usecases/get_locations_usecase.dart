import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/inventory_repository.dart';

/// One action: fetchLocations.
class GetLocationsUseCase implements UseCase<List<String>, NoParams> {
  GetLocationsUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<String>>> call(NoParams params) =>
      _repository.fetchLocations();
}
