import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/transfer_repository.dart';

/// One action: dispatchTransfer.
class DispatchTransferUseCase implements UseCase<Unit, String> {
  DispatchTransferUseCase(this._repository);

  final TransferRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.dispatchTransfer(params);
}
