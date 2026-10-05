import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/inventory_records.dart';
import '../entities/inventory_report_row.dart';
import '../entities/product.dart';

/// What the presentation layer (through use cases) can ask of inventory.
/// Every method returns `Either<Failure, T>`; the data layer maps its
/// exceptions to failures (see `data/repositories/`).
abstract interface class InventoryRepository {
  /// 'on-order' = receivableStatus Pending; 'in-stock' = everything else not
  /// deleted. Sorted newest first.
  Future<Either<Failure, List<Product>>> fetchProducts(InventoryType type);

  /// One row per serial across all products (React report rows).
  Future<Either<Failure, List<InventoryReportRow>>> fetchReportRows();

  /// Archived serials moved to Damaged Inventory, newest first.
  Future<Either<Failure, List<DamagedRecord>>> fetchDamaged();

  /// Archive of deleted products / serials, newest first.
  Future<Either<Failure, List<DeletedProduct>>> fetchDeleted();

  /// Archives to deleted inventory (React: copies to `deleted_products`,
  /// then removes).
  Future<Either<Failure, Unit>> deleteProduct(String id, DeletedBy by);

  /// Soft-deletes a single serial. The parent product goes away only when its
  /// last serial is deleted.
  Future<Either<Failure, Unit>> deleteSerial(
    String productId,
    String serialNumber,
    DeletedBy by,
  );

  /// On-order -> received: receivableStatus Received, status Available.
  Future<Either<Failure, Unit>> receiveProduct(String id);

  /// Appends [serials] to a product. Cost is averaged over units on hand and
  /// the sell price only ever rises (owner decisions 2 and 3).
  Future<Either<Failure, Unit>> addStock({
    required String productId,
    required List<String> serials,
    required Map<String, String> serialCities,
    required double sellPrice,
    required double costPrice,
  });

  /// Serials in [serials] already used by any other live or sold unit
  /// (trimmed, case-insensitive).
  Future<Either<Failure, List<String>>> findExistingSerials(
    List<String> serials, {
    String? exceptProductId,
  });

  /// Finds the product holding a live [serial]. With [productId], looks the
  /// serial up on that product directly, which also works for sold serials.
  /// `Right(null)` = not found.
  Future<Either<Failure, ReturnLookup?>> lookupSerial(
    String serial, {
    String? productId,
  });

  /// Most recent invoices (newest first).
  Future<Either<Failure, List<InvoiceRef>>> fetchRecentInvoices({
    int limit = 8,
  });

  /// Returns a serial to stock, or moves it to Damaged Inventory. If an
  /// [invoice] is given it is reversed and moved to Deleted Invoices.
  Future<Either<Failure, bool>> returnSerial({
    required String productId,
    required String serial,
    required bool damaged,
    required DeletedBy by,
    String? reason,
    InvoiceRef? invoice,
  });

  Future<Either<Failure, List<String>>> fetchLocations();

  /// Adds (and persists) a location; returns the updated sorted list.
  Future<Either<Failure, List<String>>> addLocation(String name);
}
