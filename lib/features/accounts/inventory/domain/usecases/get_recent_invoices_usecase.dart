import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_records.dart';
import '../repositories/inventory_repository.dart';

class GetRecentInvoicesParams extends Equatable {
  const GetRecentInvoicesParams({this.limit = 8});

  final int limit;

  @override
  List<Object?> get props => [limit];
}

/// One action: fetchRecentInvoices.
class GetRecentInvoicesUseCase
    implements UseCase<List<InvoiceRef>, GetRecentInvoicesParams> {
  GetRecentInvoicesUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<InvoiceRef>>> call(
    GetRecentInvoicesParams params,
  ) => _repository.fetchRecentInvoices(limit: params.limit);
}
