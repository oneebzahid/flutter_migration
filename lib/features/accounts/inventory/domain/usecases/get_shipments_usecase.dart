import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/catalog.dart';
import '../repositories/catalog_repository.dart';

/// One action: fetchShipments.
class GetShipmentsUseCase implements UseCase<List<Shipment>, NoParams> {
  GetShipmentsUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, List<Shipment>>> call(NoParams params) =>
      _repository.fetchShipments();
}
