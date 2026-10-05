import '../../domain/entities/catalog.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_transfer.dart';
import '../../domain/entities/supplier_payment.dart';

/// Raw inventory source (Firestore/Supabase/in-memory). Methods throw the
/// typed exceptions in `core/error/exceptions.dart` (`ValidationException`
/// for business-rule failures with a user-facing message); the repository
/// implementations turn them into `Failure`s.
///
/// One class serves the inventory, catalog and transfer repositories because
/// they work on the same data.
abstract interface class InventoryDataSource {
  // ───────── Inventory ─────────
  Future<List<Product>> fetchProducts(InventoryType type);
  Future<List<InventoryReportRow>> fetchReportRows();
  Future<List<DamagedRecord>> fetchDamaged();
  Future<List<DeletedProduct>> fetchDeleted();
  Future<void> deleteProduct(String id, DeletedBy by);
  Future<void> deleteSerial(
    String productId,
    String serialNumber,
    DeletedBy by,
  );
  Future<void> receiveProduct(String id);
  Future<void> addStock({
    required String productId,
    required List<String> serials,
    required Map<String, String> serialCities,
    required double sellPrice,
    required double costPrice,
  });
  Future<List<String>> findExistingSerials(
    List<String> serials, {
    String? exceptProductId,
  });
  Future<ReturnLookup?> lookupSerial(String serial, {String? productId});
  Future<List<InvoiceRef>> fetchRecentInvoices({int limit = 8});
  Future<bool> returnSerial({
    required String productId,
    required String serial,
    required bool damaged,
    required DeletedBy by,
    String? reason,
    InvoiceRef? invoice,
  });
  Future<List<String>> fetchLocations();
  Future<List<String>> addLocation(String name);

  // ───────── Catalog ─────────
  Future<List<String>> fetchBrands();
  Future<List<ModelOption>> fetchModels(String brand);
  Future<void> addBrand(String name);
  Future<void> addModel(String brand, String model);
  Future<List<Shipment>> fetchShipments();
  Future<String> generateTransactionId();
  Future<void> saveModelProfile(String brand, ModelOption profile);
  Future<Product> createProduct(NewProductDraft draft);

  // ───────── Transfers ─────────
  Future<List<ProductTransfer>> fetchTransfers();
  Future<Set<String>> fetchReservedSerials();
  Future<List<ProductTransfer>> createTransfers(TransferRequest request);
  Future<void> dispatchTransfer(String id);
  Future<void> receiveTransfer(String id, {required String receivedBy});
  Future<void> cancelTransfer(String id);
  Future<void> deleteTransfer(String id);

  // ───────── Payables ─────────
  Future<List<Product>> fetchPayables();
  Future<List<BankAccount>> fetchBanks();
  Future<SupplierPayment> recordSupplierPayment(SupplierPaymentRequest request);
  Future<List<SupplierPayment>> fetchSupplierPayments(String productId);
}
