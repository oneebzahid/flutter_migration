import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/inventory_repository.dart';

/// One action: fetchProducts.
class GetProductsUseCase implements UseCase<List<Product>, InventoryType> {
  GetProductsUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, List<Product>>> call(InventoryType params) =>
      _repository.fetchProducts(params);
}
