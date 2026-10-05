import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/product_transfer.dart';
import '../repositories/transfer_repository.dart';

/// One action: fetchTransfers.
class GetTransfersUseCase implements UseCase<List<ProductTransfer>, NoParams> {
  GetTransfersUseCase(this._repository);

  final TransferRepository _repository;

  @override
  Future<Either<Failure, List<ProductTransfer>>> call(NoParams params) =>
      _repository.fetchTransfers();
}
