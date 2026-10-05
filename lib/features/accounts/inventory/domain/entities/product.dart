import 'package:equatable/equatable.dart';

import '../rules/inventory_logic.dart';

/// React `ProductStatus`.
enum ProductStatus {
  newItem('New'),
  inTransit('In Transit'),
  onOrder('On-Order'),
  receivable('Receivable'),
  available('Available'),
  sold('Sold'),
  damaged('Damaged'),
  returned('Returned'),
  used('Used');

  const ProductStatus(this.label);
  final String label;
}

enum BuyType {
  import('Import'),
  export('Export');

  const BuyType(this.label);
  final String label;
}

enum OwnershipType {
  credit('Credit'),
  owned('Owned');

  const OwnershipType(this.label);
  final String label;
}

enum SerialStatus {
  available('Available'),
  inTransit('In Transit'),
  damaged('Damaged'),
  returned('Returned'),
  sold('Sold');

  const SerialStatus(this.label);
  final String label;
}

/// Supplier payment status. [label] is the display text React maps to
/// (Cleared → Clear, Unpaid → Pending).
enum SupplierPaymentStatus {
  unpaid('Pending'),
  partial('Partial'),
  cleared('Clear');

  const SupplierPaymentStatus(this.label);
  final String label;
}

enum ReceivableStatus { pending, received }

/// Which list a product belongs to (React `inventoryType`).
/// 'on-order' = receivableStatus Pending; 'in-stock' = everything else.
enum InventoryType { inStock, onOrder }

/// A product batch (React `Product`). Only fields used by migrated screens are
/// modelled; later slices extend it (costing, payments, per-serial maps).
class Product extends Equatable {
  const Product({
    required this.id,
    required this.brandName,
    required this.modelName,
    required this.category,
    required this.sellPrice,
    required this.buyType,
    required this.warrantyYears,
    required this.status,
    this.costPrice,
    this.location,
    this.serialNumbers = const [],
    this.serialStatus = const {},
    this.description = '',
    this.isDamaged = false,
    this.ownershipType,
    this.supplierCost,
    this.billId,
    this.receivableStatus,
    this.expectedReceiveDate,
    this.createdAt,
    this.imageUrls = const [],
    this.stockInDateManual,
    this.supplierPaymentStatus,
    this.supplierPaidAmount,
    this.serialCities = const {},
    this.serialStockInDates = const {},
    this.serialInvoiceNumbers = const {},
  });

  final String id;
  final String brandName;
  final String modelName;
  final String category;
  final double? costPrice;
  final double sellPrice;
  final BuyType buyType;
  final int warrantyYears;
  final String? location;
  final List<String> serialNumbers;
  final Map<String, SerialStatus> serialStatus;
  final String description;
  final ProductStatus status;
  final bool isDamaged;
  final OwnershipType? ownershipType;
  final double? supplierCost;
  final String? billId;
  final ReceivableStatus? receivableStatus;
  final DateTime? expectedReceiveDate;
  final DateTime? createdAt;
  final List<String> imageUrls;
  final DateTime? stockInDateManual;
  final SupplierPaymentStatus? supplierPaymentStatus;

  /// Total paid to the supplier so far (credit stock).
  final double? supplierPaidAmount;

  /// serial -> city (per-serial location; falls back to [location]).
  final Map<String, String> serialCities;
  final Map<String, DateTime> serialStockInDates;
  final Map<String, String> serialInvoiceNumbers;

  Product copyWith({
    List<String>? serialNumbers,
    Map<String, SerialStatus>? serialStatus,
    ProductStatus? status,
    ReceivableStatus? receivableStatus,
    double? sellPrice,
    double? costPrice,
    OwnershipType? ownershipType,
    Map<String, String>? serialCities,
    Map<String, DateTime>? serialStockInDates,
    double? supplierPaidAmount,
    SupplierPaymentStatus? supplierPaymentStatus,
  }) => Product(
    id: id,
    brandName: brandName,
    modelName: modelName,
    category: category,
    sellPrice: sellPrice ?? this.sellPrice,
    buyType: buyType,
    warrantyYears: warrantyYears,
    status: status ?? this.status,
    costPrice: costPrice ?? this.costPrice,
    location: location,
    serialNumbers: serialNumbers ?? this.serialNumbers,
    serialStatus: serialStatus ?? this.serialStatus,
    description: description,
    isDamaged: isDamaged,
    ownershipType: ownershipType ?? this.ownershipType,
    supplierCost: supplierCost,
    billId: billId,
    receivableStatus: receivableStatus ?? this.receivableStatus,
    expectedReceiveDate: expectedReceiveDate,
    createdAt: createdAt,
    imageUrls: imageUrls,
    stockInDateManual: stockInDateManual,
    supplierPaymentStatus: supplierPaymentStatus ?? this.supplierPaymentStatus,
    supplierPaidAmount: supplierPaidAmount ?? this.supplierPaidAmount,
    serialCities: serialCities ?? this.serialCities,
    serialStockInDates: serialStockInDates ?? this.serialStockInDates,
    serialInvoiceNumbers: serialInvoiceNumbers,
  );

  /// Units on hand, derived from serial status (owner decision 1): never
  /// stored, so returns, damage and transfers cannot make it drift.
  int get stock => StockValuation.onHand(serialNumbers, serialStatus);

  /// What is still owed to the supplier (never negative).
  double get supplierOutstanding =>
      SupplierPaymentRules.outstanding(supplierCost, supplierPaidAmount ?? 0);

  /// React `calculateProductStats`: value = costPrice × units on hand.
  double get stockValue => (costPrice ?? 0) * stock;

  @override
  List<Object?> get props => [
    id,
    brandName,
    modelName,
    category,
    costPrice,
    sellPrice,
    buyType,
    warrantyYears,
    location,
    serialNumbers,
    serialStatus,
    description,
    status,
    isDamaged,
    ownershipType,
    supplierCost,
    billId,
    receivableStatus,
    expectedReceiveDate,
    createdAt,
    imageUrls,
    stockInDateManual,
    supplierPaymentStatus,
    supplierPaidAmount,
    serialCities,
    serialStockInDates,
    serialInvoiceNumbers,
  ];
}
