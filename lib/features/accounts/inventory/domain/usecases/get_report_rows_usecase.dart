import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/inventory_report_row.dart';
import '../repositories/inventory_repository.dart';

/// One action: fetchReportRows.
class GetReportRowsUseCase
    implements UseCase<List<InventoryReportRow>, NoParams> {
  GetReportRowsUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<InventoryReportRow>>> call(NoParams params) =>
      _repository.fetchReportRows();
}
