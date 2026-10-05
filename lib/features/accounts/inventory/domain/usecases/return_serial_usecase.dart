import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

class ReturnSerialParams extends Equatable {
  const ReturnSerialParams({
    required this.productId,
    required this.serial,
    required this.damaged,
    required this.by,
    this.reason,
    this.invoice,
  });

  final String productId;
  final String serial;
  final bool damaged;
  final DeletedBy by;
  final String? reason;
  final InvoiceRef? invoice;

  @override
  List<Object?> get props => [productId, serial, damaged, by, reason, invoice];
}

/// One action: returnSerial.
class ReturnSerialUseCase implements UseCase<bool, ReturnSerialParams> {
  ReturnSerialUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, bool>> call(ReturnSerialParams params) =>
      _repository.returnSerial(
        productId: params.productId,
        serial: params.serial,
        damaged: params.damaged,
        by: params.by,
        reason: params.reason,
        invoice: params.invoice,
      );
}
