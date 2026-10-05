import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/catalog.dart';
import '../entities/product.dart';

/// Brand / model / shipment lookups and product creation used by the entry
/// forms.
abstract interface class CatalogRepository {
  Future<Either<Failure, List<String>>> fetchBrands();
  Future<Either<Failure, List<ModelOption>>> fetchModels(String brand);
  Future<Either<Failure, Unit>> addBrand(String name);
  Future<Either<Failure, Unit>> addModel(String brand, String model);

  /// Shipments that still have units to stock in (not cancelled).
  Future<Either<Failure, List<Shipment>>> fetchShipments();

  /// Next transaction id for the entry (React `generateInventoryTransactionId`).
  Future<Either<Failure, String>> generateTransactionId();

  /// Remembers the values used for a model, to pre-fill the next entry.
  Future<Either<Failure, Unit>> saveModelProfile(
    String brand,
    ModelOption profile,
  );

  /// Creates a product. Fails with a `ValidationFailure` for duplicate
  /// serials / an exact duplicate product, or when a shipment line has too
  /// few units left.
  Future<Either<Failure, Product>> createProduct(NewProductDraft draft);
}
