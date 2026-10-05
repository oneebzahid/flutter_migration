import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/catalog.dart';
import '../entities/product.dart';
import '../repositories/catalog_repository.dart';

/// One action: createProduct.
class CreateProductUseCase implements UseCase<Product, NewProductDraft> {
  CreateProductUseCase(this._repository);

  final CatalogRepository _repository;

  @override
  Future<Either<Failure, Product>> call(NewProductDraft params) =>
      _repository.createProduct(params);
}
