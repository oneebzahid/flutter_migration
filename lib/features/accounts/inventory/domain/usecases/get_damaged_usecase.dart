import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

/// One action: fetchDamaged.
class GetDamagedUseCase implements UseCase<List<DamagedRecord>, NoParams> {
  GetDamagedUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<DamagedRecord>>> call(NoParams params) =>
      _repository.fetchDamaged();
}
