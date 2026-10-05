import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/product_transfer.dart';
import '../repositories/transfer_repository.dart';

/// One action: createTransfers.
class CreateTransfersUseCase
    implements UseCase<List<ProductTransfer>, TransferRequest> {
  CreateTransfersUseCase(this._repository);

  final TransferRepository _repository;

  @override
  Future<Either<Failure, List<ProductTransfer>>> call(TransferRequest params) =>
      _repository.createTransfers(params);
}
