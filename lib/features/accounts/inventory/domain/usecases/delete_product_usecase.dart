import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

class DeleteProductParams extends Equatable {
  const DeleteProductParams({required this.id, required this.by});

  final String id;
  final DeletedBy by;

  @override
  List<Object?> get props => [id, by];
}

/// One action: deleteProduct.
class DeleteProductUseCase implements UseCase<Unit, DeleteProductParams> {
  DeleteProductUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(DeleteProductParams params) =>
      _repository.deleteProduct(params.id, params.by);
}
