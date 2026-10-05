import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/inventory_repository.dart';

/// One action: addLocation.
class AddLocationUseCase implements UseCase<List<String>, String> {
  AddLocationUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<String>>> call(String params) =>
      _repository.addLocation(params);
}
