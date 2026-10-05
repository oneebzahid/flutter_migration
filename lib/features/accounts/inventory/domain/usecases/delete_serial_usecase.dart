import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

class DeleteSerialParams extends Equatable {
  const DeleteSerialParams({
    required this.productId,
    required this.serialNumber,
    required this.by,
  });

  final String productId;
  final String serialNumber;
  final DeletedBy by;

  @override
  List<Object?> get props => [productId, serialNumber, by];
}

/// One action: deleteSerial.
class DeleteSerialUseCase implements UseCase<Unit, DeleteSerialParams> {
  DeleteSerialUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(DeleteSerialParams params) => _repository
      .deleteSerial(params.productId, params.serialNumber, params.by);
}
