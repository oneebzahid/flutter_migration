import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/transfer_repository.dart';

/// One action: fetchReservedSerials.
class GetReservedSerialsUseCase implements UseCase<Set<String>, NoParams> {
  GetReservedSerialsUseCase(this._repository);

  final TransferRepository _repository;

  @override
  Future<Either<Failure, Set<String>>> call(NoParams params) =>
      _repository.fetchReservedSerials();
}
