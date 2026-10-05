import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/transfer_repository.dart';

/// One action: deleteTransfer.
class DeleteTransferUseCase implements UseCase<Unit, String> {
  DeleteTransferUseCase(this._repository);

  final TransferRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.deleteTransfer(params);
}
