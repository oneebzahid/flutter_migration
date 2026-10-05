import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/inventory_datasource.dart';

/// Bridges [InventoryDataSource] (throws exceptions) to [CatalogRepository]
/// (returns `Either<Failure, T>`). The only try/catch lives in `guardCall`.
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._source);

  final InventoryDataSource _source;

  @override
  Future<Either<Failure, List<String>>> fetchBrands() =>
      guardCall(() => _source.fetchBrands(), fallback: 'Failed to load brands');

  @override
  Future<Either<Failure, List<ModelOption>>> fetchModels(String brand) =>
      guardCall(
        () => _source.fetchModels(brand),
        fallback: 'Something went wrong. Please try again.',
      );

  @override
  Future<Either<Failure, Unit>> addBrand(String name) => guardCall(() async {
    await _source.addBrand(name);
    return unit;
  }, fallback: 'Failed to save brand');

  @override
  Future<Either<Failure, Unit>> addModel(String brand, String model) =>
      guardCall(() async {
        await _source.addModel(brand, model);
        return unit;
      }, fallback: 'Failed to save model');

  @override
  Future<Either<Failure, List<Shipment>>> fetchShipments() => guardCall(
    () => _source.fetchShipments(),
    fallback: 'Could not load shipments',
  );

  @override
  Future<Either<Failure, String>> generateTransactionId() => guardCall(
    () => _source.generateTransactionId(),
    fallback: 'Something went wrong. Please try again.',
  );

  @override
  Future<Either<Failure, Unit>> saveModelProfile(
    String brand,
    ModelOption profile,
  ) => guardCall(() async {
    await _source.saveModelProfile(brand, profile);
    return unit;
  }, fallback: 'Something went wrong. Please try again.');

  @override
  Future<Either<Failure, Product>> createProduct(NewProductDraft draft) =>
      guardCall(
        () => _source.createProduct(draft),
        fallback: 'Failed to save inventory. Please try again.',
      );
}
