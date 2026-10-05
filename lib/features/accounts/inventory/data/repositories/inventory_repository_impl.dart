import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_datasource.dart';

/// Bridges [InventoryDataSource] (throws exceptions) to [InventoryRepository]
/// (returns `Either<Failure, T>`). The only try/catch lives in `guardCall`.
class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._source);

  final InventoryDataSource _source;

  @override
  Future<Either<Failure, List<Product>>> fetchProducts(InventoryType type) =>
      guardCall(
        () => _source.fetchProducts(type),
        fallback: 'Failed to fetch products',
      );

  @override
  Future<Either<Failure, List<InventoryReportRow>>> fetchReportRows() =>
      guardCall(
        () => _source.fetchReportRows(),
        fallback: 'Failed to load inventory',
      );

  @override
  Future<Either<Failure, List<DamagedRecord>>> fetchDamaged() => guardCall(
    () => _source.fetchDamaged(),
    fallback: 'Failed to load damaged inventory',
  );

  @override
  Future<Either<Failure, List<DeletedProduct>>> fetchDeleted() => guardCall(
    () => _source.fetchDeleted(),
    fallback: 'Failed to load deleted inventory',
  );

  @override
  Future<Either<Failure, Unit>> deleteProduct(String id, DeletedBy by) =>
      guardCall(() async {
        await _source.deleteProduct(id, by);
        return unit;
      }, fallback: 'Failed to delete product');

  @override
  Future<Either<Failure, Unit>> deleteSerial(
    String productId,
    String serialNumber,
    DeletedBy by,
  ) => guardCall(() async {
    await _source.deleteSerial(productId, serialNumber, by);
    return unit;
  }, fallback: 'Failed to delete item. Please try again.');

  @override
  Future<Either<Failure, Unit>> receiveProduct(String id) =>
      guardCall(() async {
        await _source.receiveProduct(id);
        return unit;
      }, fallback: 'Failed to move product to stock');

  @override
  Future<Either<Failure, Unit>> addStock({
    required String productId,
    required List<String> serials,
    required Map<String, String> serialCities,
    required double sellPrice,
    required double costPrice,
  }) => guardCall(() async {
    await _source.addStock(
      productId: productId,
      serials: serials,
      serialCities: serialCities,
      sellPrice: sellPrice,
      costPrice: costPrice,
    );
    return unit;
  }, fallback: 'Failed to update product');

  @override
  Future<Either<Failure, List<String>>> findExistingSerials(
    List<String> serials, {
    String? exceptProductId,
  }) => guardCall(
    () =>
        _source.findExistingSerials(serials, exceptProductId: exceptProductId),
    fallback: 'Something went wrong. Please try again.',
  );

  @override
  Future<Either<Failure, ReturnLookup?>> lookupSerial(
    String serial, {
    String? productId,
  }) => guardCall(
    () => _source.lookupSerial(serial, productId: productId),
    fallback: 'Failed to search for serial number',
  );

  @override
  Future<Either<Failure, List<InvoiceRef>>> fetchRecentInvoices({
    int limit = 8,
  }) => guardCall(
    () => _source.fetchRecentInvoices(limit: limit),
    fallback: 'Something went wrong. Please try again.',
  );

  @override
  Future<Either<Failure, bool>> returnSerial({
    required String productId,
    required String serial,
    required bool damaged,
    required DeletedBy by,
    String? reason,
    InvoiceRef? invoice,
  }) => guardCall(
    () => _source.returnSerial(
      productId: productId,
      serial: serial,
      damaged: damaged,
      by: by,
      reason: reason,
      invoice: invoice,
    ),
    fallback: 'Failed to process return',
  );

  @override
  Future<Either<Failure, List<String>>> fetchLocations() => guardCall(
    () => _source.fetchLocations(),
    fallback: 'Something went wrong. Please try again.',
  );

  @override
  Future<Either<Failure, List<String>>> addLocation(String name) => guardCall(
    () => _source.addLocation(name),
    fallback: 'Could not save the location',
  );
}
