import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/inventory_repository.dart';

/// One action: receiveProduct.
class ReceiveProductUseCase implements UseCase<Unit, String> {
  ReceiveProductUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.receiveProduct(params);
}
