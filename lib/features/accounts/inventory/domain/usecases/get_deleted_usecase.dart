import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

/// One action: fetchDeleted.
class GetDeletedUseCase implements UseCase<List<DeletedProduct>, NoParams> {
  GetDeletedUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<DeletedProduct>>> call(NoParams params) =>
      _repository.fetchDeleted();
}
