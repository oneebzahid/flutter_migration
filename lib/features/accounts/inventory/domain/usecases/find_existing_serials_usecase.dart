import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/inventory_repository.dart';

class FindExistingSerialsParams extends Equatable {
  const FindExistingSerialsParams({
    required this.serials,
    this.exceptProductId,
  });

  final List<String> serials;
  final String? exceptProductId;

  @override
  List<Object?> get props => [serials, exceptProductId];
}

/// One action: findExistingSerials.
class FindExistingSerialsUseCase
    implements UseCase<List<String>, FindExistingSerialsParams> {
  FindExistingSerialsUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<String>>> call(
    FindExistingSerialsParams params,
  ) => _repository.findExistingSerials(
    params.serials,
    exceptProductId: params.exceptProductId,
  );
}
