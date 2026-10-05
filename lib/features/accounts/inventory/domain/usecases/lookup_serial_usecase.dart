import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

class LookupSerialParams extends Equatable {
  const LookupSerialParams({required this.serial, this.productId});

  final String serial;
  final String? productId;

  @override
  List<Object?> get props => [serial, productId];
}

/// One action: lookupSerial.
class LookupSerialUseCase
    implements UseCase<ReturnLookup?, LookupSerialParams> {
  LookupSerialUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, ReturnLookup?>> call(LookupSerialParams params) =>
      _repository.lookupSerial(params.serial, productId: params.productId);
}
