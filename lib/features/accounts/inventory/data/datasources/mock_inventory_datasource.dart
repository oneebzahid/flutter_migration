import '../../../../../core/error/exceptions.dart';
import '../../domain/entities/catalog.dart';
import 'inventory_datasource.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/rules/inventory_logic.dart';
import '../../domain/rules/transfer_rules.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_transfer.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/rules/payable_rules.dart';

/// In-memory stand-in for Firestore (`products`, `deleted_products`,
/// `damaged_products`, invoices, `appConfig/inventoryLocations`).
/// Seed data is invented for UI testing only; it is not production data.
class MockInventoryDataSource implements InventoryDataSource {
  MockInventoryDataSource({this.latency = const Duration(milliseconds: 500)}) {
    _seedProducts();
    _seedSold();
    _seedInvoices();
    _seedDeletedAndDamaged();
  }

  final Duration latency;
  final List<Product> _products = [];
  final List<InventoryReportRow> _soldRows = [];
  final List<InvoiceRef> _invoices = [];
  final List<DeletedProduct> _deleted = [];
  final List<DamagedRecord> _damaged = [];
  final List<String> _locations = [
    'Abu Dhabi Showroom',
    'Dubai Warehouse',
    'Riyadh Store',
  ];

  /// Invoices moved to "Deleted Invoices" by a return (visible to tests).
  final List<InvoiceRef> deletedInvoices = [];

  final List<ProductTransfer> _transfers = [];
  final List<SupplierPayment> _payments = [];
  final Map<String, SupplierPayment> _paymentRequests = {};
  final List<BankAccount> _banks = const [
    // Simple fixed list: there is no Banks module (it was removed); the form
    // only needs a name to record on the payment.
    BankAccount(id: 'b1', name: 'Emirates NBD'),
    BankAccount(id: 'b2', name: 'Mashreq Bank'),
    BankAccount(id: 'b3', name: 'Habib Bank'),
  ].toList();
  final Map<String, List<ProductTransfer>> _requests = {};

  int _seq = 0;

  Future<void> _wait() => Future<void>.delayed(latency);

  int _index(String id) {
    final i = _products.indexWhere((p) => p.id == id);
    if (i < 0) throw const ValidationException('Product not found.');
    return i;
  }

  // ───────────────────────── Seed data ─────────────────────────

  void _seedProducts() {
    final now = DateTime.now();
    List<String> serials(String prefix, int n) => [
      for (var i = 1; i <= n; i++) '$prefix-${i.toString().padLeft(4, '0')}',
    ];

    Product p(
      String id,
      String brand,
      String model,
      String category,
      double cost,
      double sell,
      int stock,
      String? location,
      ProductStatus status, {
      BuyType buy = BuyType.import,
      int warranty = 1,
      OwnershipType? owner,
      double? supplierCost,
      ReceivableStatus? receivable,
      int? expectedInDays,
      int ageDays = 3,
      String description = '',
      int? manualDaysAgo,
      SupplierPaymentStatus? pay,
    }) {
      final sl = serials(id.toUpperCase(), stock);
      return Product(
        id: id,
        brandName: brand,
        modelName: model,
        category: category,
        costPrice: cost,
        sellPrice: sell,
        buyType: buy,
        warrantyYears: warranty,
        location: location,
        serialNumbers: sl,
        serialStatus: {for (final s in sl) s: SerialStatus.available},
        status: status,
        description: description,
        ownershipType: owner,
        supplierCost: supplierCost,
        receivableStatus: receivable,
        expectedReceiveDate: expectedInDays == null
            ? null
            : now.add(Duration(days: expectedInDays)),
        createdAt: now.subtract(Duration(days: ageDays)),
        billId: receivable == null ? null : 'BILL-${id.toUpperCase()}',
        stockInDateManual: manualDaysAgo == null
            ? null
            : now.subtract(Duration(days: manualDaysAgo)),
        supplierPaymentStatus: pay,
        supplierPaidAmount: supplierCost == null
            ? null
            : switch (pay) {
                SupplierPaymentStatus.cleared => supplierCost,
                SupplierPaymentStatus.partial => supplierCost / 2,
                _ => 0,
              },
      );
    }

    _products.addAll([
      p(
        'p01',
        'Garrett',
        'Metal Detector ATX',
        'Finished Goods',
        185000,
        240000,
        6,
        'Dubai Warehouse',
        ProductStatus.available,
        owner: OwnershipType.owned,
        warranty: 2,
        ageDays: 2,
        manualDaysAgo: 4,
        description: 'Pulse induction, waterproof coil.',
      ),
      p(
        'p02',
        'Garrett',
        'Super Scanner V',
        'Finished Goods',
        21000,
        29500,
        24,
        'Dubai Warehouse',
        ProductStatus.available,
        owner: OwnershipType.owned,
        ageDays: 5,
      ),
      p(
        'p03',
        'Minelab',
        'Equinox 800',
        'Finished Goods',
        142000,
        189000,
        4,
        'Abu Dhabi Showroom',
        ProductStatus.newItem,
        owner: OwnershipType.credit,
        supplierCost: 142000,
        warranty: 3,
        ageDays: 1,
        pay: SupplierPaymentStatus.partial,
      ),
      p(
        'p04',
        'Minelab',
        'Manticore',
        'Finished Goods',
        260000,
        335000,
        2,
        'Riyadh Store',
        ProductStatus.inTransit,
        owner: OwnershipType.credit,
        supplierCost: 260000,
        ageDays: 6,
        pay: SupplierPaymentStatus.unpaid,
      ),
      p(
        'p05',
        'Hikvision',
        'DS-2CD2143 Camera',
        'Finished Goods',
        9800,
        14500,
        60,
        'Dubai Warehouse',
        ProductStatus.available,
        buy: BuyType.export,
        owner: OwnershipType.owned,
        ageDays: 12,
      ),
      p(
        'p06',
        'Hikvision',
        'DS-7608 NVR',
        'Finished Goods',
        32000,
        44000,
        0,
        'Dubai Warehouse',
        ProductStatus.sold,
        owner: OwnershipType.owned,
        ageDays: 20,
      ),
      p(
        'p07',
        'Dahua',
        'IPC-HFW Dome',
        'Finished Goods',
        8400,
        12900,
        35,
        'Abu Dhabi Showroom',
        ProductStatus.available,
        owner: OwnershipType.owned,
        ageDays: 9,
      ),
      p(
        'p08',
        'Dahua',
        'XVR5108 Recorder',
        'Finished Goods',
        15500,
        22000,
        12,
        'Riyadh Store',
        ProductStatus.used,
        owner: OwnershipType.owned,
        ageDays: 30,
      ),
      p(
        'p09',
        'Generic',
        'Coil 11" DD',
        'Accessories',
        6200,
        9800,
        18,
        'Dubai Warehouse',
        ProductStatus.available,
        owner: OwnershipType.owned,
        ageDays: 15,
      ),
      p(
        'p10',
        'Generic',
        'Headphones WS-6',
        'Accessories',
        2400,
        4100,
        40,
        null,
        ProductStatus.returned,
        owner: OwnershipType.owned,
        ageDays: 18,
      ),
      p(
        'p11',
        'Garrett',
        'Carry Bag Pro',
        'Accessories',
        1800,
        3200,
        0,
        'Abu Dhabi Showroom',
        ProductStatus.damaged,
        owner: OwnershipType.owned,
        ageDays: 25,
      ),
      // On-order (receivable pending)
      p(
        'p12',
        'Minelab',
        'CTX 3030',
        'Finished Goods',
        210000,
        275000,
        3,
        'Dubai Warehouse',
        ProductStatus.onOrder,
        receivable: ReceivableStatus.pending,
        expectedInDays: 7,
        owner: OwnershipType.credit,
        supplierCost: 210000,
        ageDays: 4,
      ),
      p(
        'p13',
        'Hikvision',
        'DS-2DE PTZ',
        'Finished Goods',
        54000,
        72000,
        8,
        'Riyadh Store',
        ProductStatus.onOrder,
        receivable: ReceivableStatus.pending,
        expectedInDays: 14,
        ageDays: 2,
      ),
      p(
        'p14',
        'Dahua',
        'SD49425 PTZ',
        'Finished Goods',
        48000,
        66500,
        5,
        'Abu Dhabi Showroom',
        ProductStatus.onOrder,
        receivable: ReceivableStatus.pending,
        expectedInDays: -2,
        ageDays: 10,
      ),
    ]);
  }

  void _seedSold() {
    final now = DateTime.now();
    var inv = 1040;
    void sold(
      String id,
      String brand,
      String model,
      String type,
      String loc,
      OwnershipType own,
      double cost,
      int n,
      int daysAgo,
    ) {
      for (var k = 0; k < n; k++) {
        final credit = own == OwnershipType.credit;
        final pay = SupplierPaymentStatus.values[(k + n) % 3];
        _soldRows.add(
          InventoryReportRow(
            productId: id,
            brandName: brand,
            modelName: model,
            serialNumber:
                '${id.toUpperCase()}-S${(k + 1).toString().padLeft(3, '0')}',
            type: type,
            location: loc,
            ownership: own,
            condition: 'New',
            currentStatus: StockState.sold,
            stockInDateAuto: now.subtract(Duration(days: daysAgo + k)),
            soldDate: now.subtract(Duration(days: (daysAgo - 5).clamp(1, 60))),
            // Two serials share one invoice.
            invoiceNumber: 'INV-${inv + k ~/ 2}',
            supplierCost: credit ? cost : null,
            purchasingCost: credit ? null : cost,
            supplierPaymentStatus: credit ? pay : null,
            supplierPaidAmount: credit && pay != SupplierPaymentStatus.unpaid
                ? cost
                : null,
          ),
        );
      }
      inv += (n + 1) ~/ 2;
    }

    sold(
      'p01',
      'Garrett',
      'Metal Detector ATX',
      'Finished Goods',
      'Dubai Warehouse',
      OwnershipType.owned,
      185000,
      2,
      22,
    );
    sold(
      'p02',
      'Garrett',
      'Super Scanner V',
      'Finished Goods',
      'Dubai Warehouse',
      OwnershipType.owned,
      21000,
      3,
      28,
    );
    sold(
      'p03',
      'Minelab',
      'Equinox 800',
      'Finished Goods',
      'Abu Dhabi Showroom',
      OwnershipType.credit,
      142000,
      2,
      16,
    );
    sold(
      'p05',
      'Hikvision',
      'DS-2CD2143 Camera',
      'Finished Goods',
      'Dubai Warehouse',
      OwnershipType.owned,
      9800,
      4,
      35,
    );
    sold(
      'p06',
      'Hikvision',
      'DS-7608 NVR',
      'Finished Goods',
      'Dubai Warehouse',
      OwnershipType.owned,
      32000,
      4,
      40,
    );
  }

  void _seedInvoices() {
    const customers = [
      'Al Noor Trading',
      'Gulf Security LLC',
      'Desert Gold Traders',
      'Falcon Systems',
      'Sahara Detectors',
    ];
    final byNumber = <String, List<InventoryReportRow>>{};
    for (final r in _soldRows) {
      byNumber.putIfAbsent(r.invoiceNumber!, () => []).add(r);
    }
    var n = 0;
    for (final e in byNumber.entries) {
      final byProduct = <String, List<String>>{};
      var total = 0.0;
      for (final r in e.value) {
        byProduct.putIfAbsent(r.productId, () => []).add(r.serialNumber);
        total += _products.firstWhere((p) => p.id == r.productId).sellPrice;
      }
      _invoices.add(
        InvoiceRef(
          id: 'inv-doc-${e.key}',
          invoiceNumber: e.key,
          customerName: customers[n++ % customers.length],
          date: e.value.first.soldDate ?? DateTime.now(),
          totalAmount: total,
          lines: [
            for (final x in byProduct.entries)
              InvoiceLine(productId: x.key, serials: x.value),
          ],
        ),
      );
    }
  }

  void _seedDeletedAndDamaged() {
    final now = DateTime.now();
    const admin = DeletedBy(
      uid: 'demo-admin',
      email: 'admin@demo.com',
      name: 'Demo Admin',
    );
    const sara = DeletedBy(
      uid: 'u-sara',
      email: 'sara.ali@bullion.com',
      name: 'Sara Ali',
    );
    final base = _products.firstWhere((p) => p.id == 'p09');
    // Whole-product deletion.
    _deleted.add(
      DeletedProduct(
        archiveId: 'arch-seed-1',
        originalId: 'p-old-1',
        product: base.copyWith(),
        deletedAt: now.subtract(const Duration(days: 3, hours: 2)),
        deletedBy: admin,
      ),
    );
    // Single-serial deletion, location only known per serial.
    _deleted.add(
      DeletedProduct(
        archiveId: 'arch-seed-2',
        originalId: 'p05',
        product: const Product(
          id: 'p05',
          brandName: 'Hikvision',
          modelName: 'DS-2CD2143 Camera',
          category: 'Finished Goods',
          sellPrice: 14500,
          buyType: BuyType.export,
          warrantyYears: 0,
          status: ProductStatus.available,
          serialNumbers: ['P05-0099'],
          serialCities: {'P05-0099': 'Dubai Warehouse'},
        ),
        deletedAt: now.subtract(const Duration(days: 1)),
        deletedBy: sara,
        serialScope: true,
      ),
    );
    _damaged.addAll([
      DamagedRecord(
        id: 'dmg-seed-1',
        productId: 'p01',
        brandName: 'Garrett',
        modelName: 'Metal Detector ATX',
        serialNumber: 'P01-0777',
        location: 'Dubai Warehouse',
        reason: 'Cracked coil housing on return',
        damagedAt: now.subtract(const Duration(days: 2)),
        damagedBy: 'admin@demo.com',
      ),
      DamagedRecord(
        id: 'dmg-seed-2',
        productId: 'p07',
        brandName: 'Dahua',
        modelName: 'IPC-HFW Dome',
        serialNumber: 'P07-0888',
        damagedAt: now.subtract(const Duration(days: 9)),
      ),
    ]);
  }

  // ───────────────────────── Lists ─────────────────────────

  @override
  Future<List<Product>> fetchProducts(InventoryType type) async {
    await _wait();
    final isOrder = type == InventoryType.onOrder;
    final list =
        _products
            .where(
              (p) => isOrder
                  ? p.receivableStatus == ReceivableStatus.pending
                  : p.receivableStatus != ReceivableStatus.pending,
            )
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
    return list;
  }

  @override
  Future<List<DamagedRecord>> fetchDamaged() async {
    await _wait();
    return [..._damaged]..sort((a, b) => b.damagedAt.compareTo(a.damagedAt));
  }

  @override
  Future<List<DeletedProduct>> fetchDeleted() async {
    await _wait();
    return [..._deleted]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  }

  String _condition(Product p) => switch (p.status) {
    ProductStatus.used => 'Used',
    ProductStatus.damaged => 'Damaged',
    ProductStatus.returned => 'Returned',
    _ => 'New',
  };

  @override
  Future<List<InventoryReportRow>> fetchReportRows() async {
    await _wait();
    final rows = <InventoryReportRow>[];
    for (final p in _products) {
      if (p.receivableStatus == ReceivableStatus.pending) continue;
      for (var n = 0; n < p.serialNumbers.length; n++) {
        final s = p.serialNumbers[n];
        final created = p.createdAt ?? DateTime.now();
        final credit = p.ownershipType == OwnershipType.credit;
        final pay = credit ? SupplierPaymentStatus.values[n % 3] : null;
        rows.add(
          InventoryReportRow(
            productId: p.id,
            brandName: p.brandName,
            modelName: p.modelName,
            serialNumber: s,
            type: p.category,
            location: p.serialCities[s] ?? p.location ?? '',
            ownership: p.ownershipType,
            condition: _condition(p),
            currentStatus: StockState.inStock,
            stockInDateAuto:
                p.serialStockInDates[s] ?? created.subtract(Duration(hours: n)),
            stockInDateManual: n % 5 == 0
                ? DateTime(created.year, created.month, created.day)
                : null,
            supplierCost: credit ? p.costPrice : null,
            purchasingCost: credit ? null : p.costPrice,
            supplierPaymentStatus: pay,
            supplierPaidAmount: switch (pay) {
              SupplierPaymentStatus.cleared => p.costPrice,
              SupplierPaymentStatus.partial => (p.costPrice ?? 0) / 2,
              _ => null,
            },
          ),
        );
      }
    }
    rows.addAll(_soldRows);
    return rows;
  }

  // ───────────────────────── Delete / receive ─────────────────────────

  DeletedProduct _archive(
    Product snapshot,
    String originalId,
    DeletedBy by, {
    bool serial = false,
  }) => DeletedProduct(
    archiveId: 'arch-${++_seq}',
    originalId: originalId,
    product: snapshot,
    deletedAt: DateTime.now(),
    deletedBy: by,
    serialScope: serial,
  );

  @override
  Future<void> deleteProduct(String id, DeletedBy by) async {
    await _wait();
    final i = _index(id);
    _deleted.add(_archive(_products[i], id, by));
    _products.removeAt(i);
  }

  @override
  Future<void> deleteSerial(
    String productId,
    String serialNumber,
    DeletedBy by,
  ) async {
    await _wait();
    // Sold history rows have no live product serial; just drop them.
    final soldIdx = _soldRows.indexWhere(
      (r) => r.productId == productId && r.serialNumber == serialNumber,
    );
    if (soldIdx >= 0) {
      _soldRows.removeAt(soldIdx);
      return;
    }
    final i = _index(productId);
    final p = _products[i];
    if (!p.serialNumbers.contains(serialNumber)) {
      throw const ValidationException('Serial not found.');
    }
    final remaining = [...p.serialNumbers]..remove(serialNumber);
    if (remaining.isEmpty) {
      // Last serial: the whole product is archived and leaves live inventory.
      _deleted.add(_archive(p, productId, by));
      _products.removeAt(i);
      return;
    }
    // Archive a one-serial snapshot, then trim the live product.
    _deleted.add(
      _archive(
        p.copyWith(
          serialNumbers: [serialNumber],
          serialCities: {
            if (p.serialCities[serialNumber] != null)
              serialNumber: p.serialCities[serialNumber]!,
          },
        ),
        productId,
        by,
        serial: true,
      ),
    );
    _products[i] = p.copyWith(
      serialNumbers: remaining,
      serialStatus: {...p.serialStatus}..remove(serialNumber),
      serialCities: {...p.serialCities}..remove(serialNumber),
      serialStockInDates: {...p.serialStockInDates}..remove(serialNumber),
    );
  }

  @override
  Future<void> receiveProduct(String id) async {
    await _wait();
    final i = _index(id);
    _products[i] = _products[i].copyWith(
      status: ProductStatus.available,
      receivableStatus: ReceivableStatus.received,
    );
  }

  // ───────────────────────── Add stock ─────────────────────────

  @override
  Future<void> addStock({
    required String productId,
    required List<String> serials,
    required Map<String, String> serialCities,
    required double sellPrice,
    required double costPrice,
  }) async {
    await _wait();
    final i = _index(productId);
    final p = _products[i];
    final clash = _serialClashes(serials, exceptProductId: null);
    if (clash.isNotEmpty) {
      throw ValidationException('Duplicate serial number: ${clash.join(', ')}');
    }
    final added = serials.map((s) => s.trim()).toList();
    // Owner decision 2/3: average over units on hand only; the sell price is
    // only ever raised by a stock-in.
    _products[i] = p.copyWith(
      serialNumbers: [...p.serialNumbers, ...added],
      serialStatus: {
        ...p.serialStatus,
        for (final s in added) s: SerialStatus.available,
      },
      serialCities: {...p.serialCities, ...serialCities},
      serialStockInDates: {
        ...p.serialStockInDates,
        for (final s in added) s: DateTime.now(),
      },
      sellPrice: StockValuation.raiseOnlySellPrice(p.sellPrice, sellPrice),
      costPrice: StockValuation.weightedAverageCost(
        availableQty: p.stock,
        availableCost: p.costPrice ?? costPrice,
        newQty: added.length,
        newCost: costPrice,
      ),
    );
  }

  /// Incoming serials already used by any live or sold unit, matched trimmed
  /// and case-insensitively (owner decision 6). Returns the incoming spelling.
  List<String> _serialClashes(List<String> serials, {String? exceptProductId}) {
    final taken = <String>{
      for (final p in _products)
        if (p.id != exceptProductId)
          for (final s in p.serialNumbers) normalizeSerial(s),
      for (final r in _soldRows) normalizeSerial(r.serialNumber),
    };
    final found = <String>{};
    for (final s in serials) {
      final n = normalizeSerial(s);
      if (n.isNotEmpty && taken.contains(n)) found.add(s.trim());
    }
    return found.toList();
  }

  @override
  Future<List<String>> findExistingSerials(
    List<String> serials, {
    String? exceptProductId,
  }) async {
    await _wait();
    return _serialClashes(serials, exceptProductId: exceptProductId);
  }
  // ───────────────────────── Returns ─────────────────────────

  InvoiceRef? _invoiceByNumber(String? number) {
    if (number == null) return null;
    for (final i in _invoices) {
      if (i.invoiceNumber == number) return i;
    }
    return null;
  }

  @override
  Future<ReturnLookup?> lookupSerial(String serial, {String? productId}) async {
    await _wait();
    final s = serial.trim();
    if (productId != null) {
      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx < 0) return null;
      final p = _products[idx];
      final sold = _soldRows.where(
        (r) => r.productId == productId && r.serialNumber == s,
      );
      if (sold.isNotEmpty) {
        return ReturnLookup(
          product: p,
          serial: s,
          invoice: _invoiceByNumber(sold.first.invoiceNumber),
        );
      }
      if (p.serialNumbers.contains(s)) {
        return ReturnLookup(
          product: p,
          serial: s,
          invoice: _invoiceByNumber(p.serialInvoiceNumbers[s]),
        );
      }
      return null;
    }
    for (final p in _products) {
      if (p.receivableStatus == ReceivableStatus.pending) continue;
      if (p.serialNumbers.contains(s)) {
        return ReturnLookup(
          product: p,
          serial: s,
          invoice: _invoiceByNumber(p.serialInvoiceNumbers[s]),
        );
      }
    }
    return null;
  }

  @override
  Future<List<InvoiceRef>> fetchRecentInvoices({int limit = 8}) async {
    await _wait();
    final list = [..._invoices]..sort((a, b) => b.date.compareTo(a.date));
    return list.take(limit).toList();
  }

  /// Puts a sold serial back into live stock (used by returns and by
  /// reversing an invoice).
  void _restoreSold(String productId, String serial) {
    _soldRows.removeWhere(
      (r) => r.productId == productId && r.serialNumber == serial,
    );
    final i = _products.indexWhere((p) => p.id == productId);
    if (i < 0) return;
    final p = _products[i];
    if (p.serialNumbers.contains(serial)) return;
    _products[i] = p.copyWith(
      serialNumbers: [...p.serialNumbers, serial],
      serialStatus: {...p.serialStatus, serial: SerialStatus.available},
      serialStockInDates: {...p.serialStockInDates, serial: DateTime.now()},
    );
  }

  @override
  Future<bool> returnSerial({
    required String productId,
    required String serial,
    required bool damaged,
    required DeletedBy by,
    String? reason,
    InvoiceRef? invoice,
  }) async {
    await _wait();
    final i = _index(productId);
    var p = _products[i];
    final wasLive = p.serialNumbers.contains(serial);
    final now = DateTime.now();

    if (damaged) {
      _damaged.add(
        DamagedRecord(
          id: 'dmg-${++_seq}',
          productId: productId,
          brandName: p.brandName,
          modelName: p.modelName,
          serialNumber: serial,
          location: p.serialCities[serial] ?? p.location ?? '',
          reason: (reason ?? '').trim(),
          damagedAt: now,
          damagedBy: by.email,
        ),
      );
      _soldRows.removeWhere(
        (r) => r.productId == productId && r.serialNumber == serial,
      );
      if (wasLive) {
        // Stock only drops for a live unit (React also drops it for a sold
        // one, which under-counts).
        p = p.copyWith(
          serialNumbers: [...p.serialNumbers]..remove(serial),
          serialStatus: {...p.serialStatus}..remove(serial),
          serialCities: {...p.serialCities}..remove(serial),
          serialStockInDates: {...p.serialStockInDates}..remove(serial),
        );
        _products[i] = p;
      }
    } else if (wasLive) {
      // Already live: refresh the stock-in date; a credit item becomes owned.
      _products[i] = p.copyWith(
        serialStatus: {...p.serialStatus, serial: SerialStatus.available},
        serialStockInDates: {...p.serialStockInDates, serial: now},
        ownershipType: p.ownershipType == OwnershipType.credit
            ? OwnershipType.owned
            : null,
      );
    } else {
      _restoreSold(productId, serial);
      final j = _index(productId);
      _products[j] = _products[j].copyWith(
        ownershipType: _products[j].ownershipType == OwnershipType.credit
            ? OwnershipType.owned
            : null,
      );
    }

    if (invoice != null) {
      // Reverse the whole invoice: every other sold serial returns to stock,
      // then the invoice moves to Deleted Invoices.
      for (final (pid, s) in invoice.serialRefs) {
        if (pid == productId && s == serial) continue;
        _restoreSold(pid, s);
      }
      _invoices.removeWhere((x) => x.id == invoice.id);
      deletedInvoices.add(invoice);
    }
    return true;
  }

  // ───────────────────────── Locations ─────────────────────────

  @override
  Future<List<String>> fetchLocations() async {
    await _wait();
    return [..._locations]..sort();
  }

  @override
  Future<List<String>> addLocation(String name) async {
    await _wait();
    final n = name.trim();
    if (n.isNotEmpty &&
        !_locations.any((l) => l.toLowerCase() == n.toLowerCase())) {
      _locations.add(n);
    }
    return [..._locations]..sort();
  }

  // ───────────────────────── Catalog (brands / models / shipments) ─────────────────────────

  /// React `KNOWN_BRANDS` (the stray junk id the costing screen appended is omitted).
  final List<String> _brands = [
    'AKAAS DETECTORS',
    'Andralian',
    'Black Dog Xtreme',
    'Bounty Hunter VLF',
    'China',
    'DHFHJ',
    'Detector',
    'Detek',
    'EKibi',
    'Fisher',
    'GEO',
    'GROGROUND',
    'GOLD XTRA',
    'GTR TURKEY',
    'Garrett',
    'Gold Star',
    'Gold Stinger X5',
    'Hira Dedector',
    'JOKER',
    'Lorenz',
    'Minelab',
    'Multimax',
    'Nokta',
    'Nokta Makro',
    'OKM',
    'OKM EXP 6000 PROFESSIONAL PLUS',
    'PMX',
    'Practice',
    'Quest',
    'Reaper 2',
    'Super Wand',
    'Teknetics',
    'WHITES',
    'X5 ID Maxx',
    'XP',
    'Hikvision',
    'Dahua',
    'Generic',
  ];

  final Map<String, List<ModelOption>> _models = {
    'Garrett': const [
      ModelOption(
        id: 'm-g1',
        name: 'Metal Detector ATX',
        costPrice: 185000,
        sellPrice: 240000,
        category: 'Finished Goods',
        description: 'Pulse induction, waterproof coil.',
      ),
      ModelOption(
        id: 'm-g2',
        name: 'Super Scanner V',
        costPrice: 21000,
        sellPrice: 29500,
        category: 'Finished Goods',
      ),
      ModelOption(
        id: 'm-g3',
        name: 'Carry Bag Pro',
        costPrice: 1800,
        sellPrice: 3200,
        category: 'Accessories',
      ),
    ],
    'Minelab': const [
      ModelOption(
        id: 'm-m1',
        name: 'Equinox 800',
        costPrice: 142000,
        sellPrice: 189000,
        category: 'Finished Goods',
      ),
      ModelOption(
        id: 'm-m2',
        name: 'Manticore',
        costPrice: 260000,
        sellPrice: 335000,
        category: 'Finished Goods',
      ),
    ],
    'Nokta': const [
      ModelOption(
        id: 'm-n1',
        name: 'Legend',
        costPrice: 1200,
        sellPrice: 1500,
        category: 'Finished Goods',
      ),
      ModelOption(
        id: 'm-n2',
        name: 'Simplex',
        costPrice: 800,
        sellPrice: 1000,
        category: 'Finished Goods',
      ),
    ],
  };

  final List<Shipment> _shipments = [
    const Shipment(
      id: 'sh1',
      number: 'SHP-001',
      brandName: 'Nokta',
      supplierName: 'ABC Trading',
      lines: [
        StockInLine(
          lineId: 'sh1-a',
          modelName: 'Legend',
          remaining: 10,
          landedUnitCost: 1200,
          goodsPerUnit: 1000,
          customsPerUnit: 100,
          freightPerUnit: 50,
          taxPerUnit: 30,
          otherPerUnit: 20,
        ),
        StockInLine(
          lineId: 'sh1-b',
          modelName: 'Simplex',
          remaining: 5,
          stocked: 3,
          landedUnitCost: 800,
          goodsPerUnit: 650,
          customsPerUnit: 70,
          freightPerUnit: 40,
          taxPerUnit: 25,
          otherPerUnit: 15,
        ),
      ],
    ),
    const Shipment(
      id: 'sh2',
      number: 'SHP-002',
      brandName: 'Garrett',
      supplierName: 'Gulf Imports',
      lines: [
        StockInLine(
          lineId: 'sh2-a',
          modelName: 'Metal Detector ATX',
          remaining: 4,
          landedUnitCost: 190000,
          goodsPerUnit: 170000,
          customsPerUnit: 12000,
          freightPerUnit: 5000,
          taxPerUnit: 2000,
          otherPerUnit: 1000,
        ),
        StockInLine(
          lineId: 'sh2-b',
          modelName: 'Super Scanner V',
          remaining: 12,
          landedUnitCost: 22000,
          goodsPerUnit: 19000,
          customsPerUnit: 1500,
          freightPerUnit: 900,
          taxPerUnit: 400,
          otherPerUnit: 200,
        ),
      ],
    ),
    const Shipment(
      id: 'sh3',
      number: 'SHP-003',
      brandName: 'Minelab',
      supplierName: 'Desert Supply',
      lines: [
        StockInLine(
          lineId: 'sh3-a',
          modelName: 'Equinox 800',
          remaining: 6,
          landedUnitCost: 150000,
          goodsPerUnit: 135000,
          customsPerUnit: 9000,
          freightPerUnit: 4000,
          taxPerUnit: 1500,
          otherPerUnit: 500,
        ),
      ],
    ),
  ];

  int _txn = 122;

  @override
  Future<List<String>> fetchBrands() async {
    await _wait();
    return ({..._brands}.toList()..sort());
  }

  @override
  Future<List<ModelOption>> fetchModels(String brand) async {
    await _wait();
    return [...?_models[brand]];
  }

  @override
  Future<void> addBrand(String name) async {
    await _wait();
    final n = name.trim();
    if (n.isNotEmpty &&
        !_brands.any((b) => b.toLowerCase() == n.toLowerCase())) {
      _brands.add(n);
    }
  }

  @override
  Future<void> addModel(String brand, String model) async {
    await _wait();
    final list = [...?_models[brand]];
    if (!list.any((m) => m.name.toLowerCase() == model.trim().toLowerCase())) {
      list.add(ModelOption(id: 'm-${++_seq}', name: model.trim()));
    }
    _models[brand] = list;
  }

  @override
  Future<List<Shipment>> fetchShipments() async {
    await _wait();
    return [
      for (final s in _shipments)
        if (s.lines.any((l) => l.remaining > 0)) s,
    ];
  }

  @override
  Future<String> generateTransactionId() async {
    await _wait();
    return 'TXN-${(++_txn).toString().padLeft(6, '0')}';
  }

  @override
  Future<void> saveModelProfile(String brand, ModelOption profile) async {
    await _wait();
    final list = [...?_models[brand]];
    final i = list.indexWhere(
      (m) => m.name.toLowerCase() == profile.name.toLowerCase(),
    );
    if (i >= 0) {
      list[i] = profile;
    } else {
      list.add(profile);
    }
    _models[brand] = list;
  }

  // ───────────────────────── Create product ─────────────────────────

  @override
  Future<Product> createProduct(NewProductDraft d) async {
    await _wait();
    final serials = d.filledSerials;

    // Serial clash with any live/sold unit (trimmed, case-insensitive).
    final clash = _serialClashes(serials);
    if (clash.isNotEmpty) {
      throw ValidationException(
        'Duplicate serial number${clash.length > 1 ? 's' : ''}: ${clash.join(', ')}',
      );
    }
    // Exact same product, price, location and serial set.
    final sortedNew = [...serials]..sort();
    for (final p in _products) {
      final sortedOld = [...p.serialNumbers]..sort();
      if (p.brandName == d.brandName &&
          p.modelName == d.modelName &&
          p.costPrice == d.costPrice &&
          p.sellPrice == d.sellPrice &&
          p.location == d.location &&
          sortedOld.length == sortedNew.length &&
          [
            for (var i = 0; i < sortedNew.length; i++)
              sortedOld[i] == sortedNew[i],
          ].every((x) => x)) {
        throw const ValidationException(
          'Duplicate inventory already exists with the same product, price, location and serial numbers.',
        );
      }
    }

    // Shipment line bookkeeping.
    if (d.shipmentId != null && d.shipmentLineId != null) {
      final si = _shipments.indexWhere((s) => s.id == d.shipmentId);
      if (si >= 0) {
        final sh = _shipments[si];
        final li = sh.lines.indexWhere((l) => l.lineId == d.shipmentLineId);
        if (li >= 0) {
          final line = sh.lines[li];
          if (d.stock > line.remaining) {
            throw ValidationException(
              'Only ${line.remaining} unit(s) remain on this line',
            );
          }
          final lines = [...sh.lines];
          lines[li] = StockInLine(
            lineId: line.lineId,
            modelName: line.modelName,
            remaining: line.remaining - d.stock,
            stocked: line.stocked + d.stock,
            landedUnitCost: line.landedUnitCost,
            goodsPerUnit: line.goodsPerUnit,
            customsPerUnit: line.customsPerUnit,
            freightPerUnit: line.freightPerUnit,
            taxPerUnit: line.taxPerUnit,
            otherPerUnit: line.otherPerUnit,
          );
          _shipments[si] = Shipment(
            id: sh.id,
            number: sh.number,
            brandName: sh.brandName,
            supplierName: sh.supplierName,
            lines: lines,
          );
        }
      }
    }

    final now = DateTime.now();
    final credit = d.ownership == OwnershipType.credit;
    final product = Product(
      id: 'p-new-${++_seq}',
      brandName: d.brandName,
      modelName: d.modelName,
      category: d.category,
      description: d.description,
      costPrice: d.costPrice,
      sellPrice: d.sellPrice,
      buyType: d.buyType,
      warrantyYears: d.warrantyYears,
      location: d.location,
      serialNumbers: serials,
      serialStatus: {for (final s in serials) s: SerialStatus.available},
      serialCities: {for (final s in serials) s: d.location},
      serialStockInDates: {for (final s in serials) s: now},
      status: d.status,
      ownershipType: d.ownership,
      supplierCost: credit ? d.costPrice : null,
      supplierPaymentStatus: credit ? SupplierPaymentStatus.unpaid : null,
      stockInDateManual: d.stockInDateManual,
      createdAt: now,
    );
    _products.add(product);
    return product;
  }

  // ───────────────────────── Product transfers ─────────────────────────
  // Each public method is one atomic step (single-threaded here; the Supabase
  // implementation must run each one in a transaction).

  Set<String> _reserved({String? exceptTransferId}) => {
    for (final t in _transfers)
      if (t.status.isOpen && t.id != exceptTransferId)
        for (final s in t.serials) normalizeSerial(s),
  };

  int _transferIndex(String id) {
    final i = _transfers.indexWhere((t) => t.id == id);
    if (i < 0) throw const ValidationException('Transfer not found.');
    return i;
  }

  @override
  Future<List<ProductTransfer>> fetchTransfers() async {
    await _wait();
    return [..._transfers]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<Set<String>> fetchReservedSerials() async {
    await _wait();
    return _reserved();
  }

  @override
  Future<List<ProductTransfer>> createTransfers(TransferRequest r) async {
    await _wait();
    final seen = _requests[r.requestId];
    if (seen != null) return seen; // double submit: same result, no duplicate

    final error = TransferRules.validate(
      transferredBy: r.transferredBy,
      from: r.from,
      to: r.to,
      lines: r.lines,
      shipmentCost: r.shipmentCost,
    );
    if (error != null) throw ValidationException(error);

    final lines = [
      for (final l in r.lines)
        if (l.serials.isNotEmpty) l,
    ];
    final reserved = _reserved();
    final used = <String>{};
    for (final l in lines) {
      final product = _products[_index(l.productId)];
      for (final s in l.serials) {
        final n = normalizeSerial(s);
        if (!used.add(n) ||
            !TransferRules.eligible(
              serial: s,
              product: product,
              from: r.from,
              reservedSerials: reserved,
            )) {
          throw ValidationException(
            'Serial $s is not available at ${r.from} (already sold, '
            'moved, or held by another transfer).',
          );
        }
      }
    }

    final shares = TransferRules.splitFreight(r.shipmentCost, lines);
    final group = 'TG-${++_seq}';
    final created = <ProductTransfer>[];
    for (var i = 0; i < lines.length; i++) {
      final p = _products[_index(lines[i].productId)];
      created.add(
        ProductTransfer(
          id: 'TR-${(++_seq).toString().padLeft(6, '0')}',
          groupId: group,
          date: r.date,
          productId: p.id,
          brandName: p.brandName,
          modelName: p.modelName,
          from: r.from,
          to: r.to,
          serials: lines[i].serials,
          transferredBy: r.transferredBy.trim(),
          shipmentCost: shares[i],
        ),
      );
    }
    _transfers.addAll(created);
    _requests[r.requestId] = created;
    return created;
  }

  void _setSerialStatus(
    String productId,
    List<String> serials,
    SerialStatus status,
  ) {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i < 0) return;
    final p = _products[i];
    _products[i] = p.copyWith(
      serialStatus: {
        ...p.serialStatus,
        for (final s in serials)
          if (p.serialNumbers.contains(s)) s: status,
      },
    );
  }

  @override
  Future<void> dispatchTransfer(String id) async {
    await _wait();
    final i = _transferIndex(id);
    final t = _transfers[i];
    if (t.status != TransferStatus.pending) {
      throw ValidationException('Only a Pending transfer can be dispatched.');
    }
    final p = _products[_index(t.productId)];
    final blocked = [
      for (final s in t.serials)
        if (!TransferRules.eligible(
          serial: s,
          product: p,
          from: t.from,
          reservedSerials: _reserved(exceptTransferId: id),
        ))
          s,
    ];
    if (blocked.isNotEmpty) {
      throw ValidationException(
        'Cannot dispatch: ${blocked.join(', ')} no longer available at ${t.from}.',
      );
    }
    _setSerialStatus(t.productId, t.serials, SerialStatus.inTransit);
    _transfers[i] = t.copyWith(status: TransferStatus.inTransit);
  }

  @override
  Future<void> receiveTransfer(String id, {required String receivedBy}) async {
    await _wait();
    final i = _transferIndex(id);
    final t = _transfers[i];
    if (t.status != TransferStatus.inTransit) {
      throw const ValidationException(
        'Only an In Transit transfer can be received.',
      );
    }
    if (receivedBy.trim().isEmpty) {
      throw const ValidationException('Enter who is receiving the stock.');
    }
    final pi = _index(t.productId);
    final p = _products[pi];
    final bad = TransferRules.notInTransit(p, t.serials);
    if (bad.isNotEmpty) {
      throw ValidationException(
        'Cannot receive: ${bad.join(', ')} is no longer In Transit '
        '(sold, damaged or changed since dispatch).',
      );
    }
    final cities = {...p.serialCities, for (final s in t.serials) s: t.to};
    final allThere = p.serialNumbers.every(
      (s) => (cities[s] ?? p.location ?? '') == t.to,
    );
    _products[pi] = Product(
      id: p.id,
      brandName: p.brandName,
      modelName: p.modelName,
      category: p.category,
      sellPrice: p.sellPrice,
      buyType: p.buyType,
      warrantyYears: p.warrantyYears,
      status: p.status,
      costPrice: p.costPrice,
      // Product location follows only when every serial is at the destination.
      location: allThere ? t.to : p.location,
      serialNumbers: p.serialNumbers,
      serialStatus: {
        ...p.serialStatus,
        for (final s in t.serials) s: SerialStatus.available,
      },
      description: p.description,
      isDamaged: p.isDamaged,
      ownershipType: p.ownershipType,
      supplierCost: p.supplierCost,
      billId: p.billId,
      receivableStatus: p.receivableStatus,
      expectedReceiveDate: p.expectedReceiveDate,
      createdAt: p.createdAt,
      imageUrls: p.imageUrls,
      stockInDateManual: p.stockInDateManual,
      supplierPaymentStatus: p.supplierPaymentStatus,
      serialCities: cities,
      // Original stock-in dates are kept so ageing stays correct.
      serialStockInDates: p.serialStockInDates,
      serialInvoiceNumbers: p.serialInvoiceNumbers,
    );
    _transfers[i] = t.copyWith(
      status: TransferStatus.received,
      receivedBy: receivedBy.trim(),
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancelTransfer(String id) async {
    await _wait();
    final i = _transferIndex(id);
    final t = _transfers[i];
    if (!t.canCancel) {
      throw ValidationException(
        'A ${t.status.label} transfer cannot be cancelled.',
      );
    }
    if (t.status == TransferStatus.inTransit) {
      _setSerialStatus(t.productId, t.serials, SerialStatus.available);
    }
    _transfers[i] = t.copyWith(status: TransferStatus.cancelled);
  }

  @override
  Future<void> deleteTransfer(String id) async {
    await _wait();
    final i = _transferIndex(id);
    final t = _transfers[i];
    switch (t.status) {
      case TransferStatus.inTransit:
        _setSerialStatus(t.productId, t.serials, SerialStatus.available);
      case TransferStatus.received:
        final pi = _products.indexWhere((p) => p.id == t.productId);
        if (pi >= 0) {
          final p = _products[pi];
          // Only serials still available at the destination go back.
          final back = [
            for (final s in t.serials)
              if (p.serialNumbers.contains(s) &&
                  (p.serialStatus[s] ?? SerialStatus.available) ==
                      SerialStatus.available &&
                  p.serialCities[s] == t.to)
                s,
          ];
          _products[pi] = p.copyWith(
            serialCities: {...p.serialCities, for (final s in back) s: t.from},
          );
        }
      case TransferStatus.pending || TransferStatus.cancelled:
        break;
    }
    _transfers.removeAt(i);
  }

  // ───────────────────────── Payables ─────────────────────────

  @override
  Future<List<Product>> fetchPayables() async {
    await _wait();
    return [
      for (final p in _products)
        if (PayableRules.isPayable(p)) p,
    ];
  }

  @override
  Future<List<BankAccount>> fetchBanks() async {
    await _wait();
    return [..._banks];
  }

  @override
  Future<List<SupplierPayment>> fetchSupplierPayments(String productId) async {
    await _wait();
    return [
      for (final p in _payments.reversed)
        if (p.productId == productId) p,
    ];
  }

  @override
  Future<SupplierPayment> recordSupplierPayment(
    SupplierPaymentRequest r,
  ) async {
    await _wait();
    final seen = _paymentRequests[r.requestId];
    if (seen != null) return seen; // double submit: same result, no 2nd payment

    final i = _index(r.productId);
    final p = _products[i];
    final error = PayableRules.validate(
      product: p,
      amount: r.amount,
      channel: r.channel,
      bankId: r.bankId,
    );
    if (error != null) throw ValidationException(error);
    final bank = r.channel == PaymentChannel.bank
        ? _banks.where((b) => b.id == r.bankId).firstOrNull
        : null;
    if (r.channel == PaymentChannel.bank && bank == null) {
      throw const ValidationException('Please select a bank account');
    }

    final paid = (p.supplierPaidAmount ?? 0) + r.amount;
    _products[i] = p.copyWith(
      supplierPaidAmount: paid,
      supplierPaymentStatus: SupplierPaymentRules.status(
        cost: p.supplierCost,
        paid: paid,
      ),
    );
    final now = DateTime.now();
    final payment = SupplierPayment(
      id: 'pay-${++_seq}',
      productId: p.id,
      label: '${p.brandName} ${p.modelName}',
      amount: r.amount,
      channel: r.channel,
      bankName: bank?.name,
      date: now,
      reference: 'SUP-PAY-${p.id}-${now.millisecondsSinceEpoch}',
    );
    _payments.add(payment);
    _paymentRequests[r.requestId] = payment;
    return payment;
  }
}
