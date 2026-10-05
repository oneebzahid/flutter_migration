import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/transfer_repository.dart';

class ReceiveTransferParams extends Equatable {
  const ReceiveTransferParams({required this.id, required this.receivedBy});

  final String id;
  final String receivedBy;

  @override
  List<Object?> get props => [id, receivedBy];
}

/// One action: receiveTransfer.
class ReceiveTransferUseCase implements UseCase<Unit, ReceiveTransferParams> {
  ReceiveTransferUseCase(this._repository);

  final TransferRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ReceiveTransferParams params) =>
      _repository.receiveTransfer(params.id, receivedBy: params.receivedBy);
}
