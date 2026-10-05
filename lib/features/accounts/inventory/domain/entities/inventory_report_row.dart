import 'package:equatable/equatable.dart';

import 'product.dart';

enum StockState {
  inStock('In Stock'),
  sold('Sold');

  const StockState(this.label);
  final String label;
}

/// One row per serial number (React `InventoryReportRow`).
class InventoryReportRow extends Equatable {
  const InventoryReportRow({
    required this.productId,
    required this.brandName,
    required this.modelName,
    required this.serialNumber,
    required this.type,
    required this.condition,
    required this.currentStatus,
    this.stockInDateAuto,
    this.stockInDateManual,
    this.location = '',
    this.ownership,
    this.soldDate,
    this.invoiceNumber,
    this.supplierCost,
    this.purchasingCost,
    this.supplierPaymentStatus,
    this.supplierPaidAmount,
  });

  final String productId;
  final String brandName;
  final String modelName;
  final String serialNumber;
  final DateTime? stockInDateAuto;
  final DateTime? stockInDateManual;

  /// Product category (React `type`).
  final String type;
  final String location;
  final OwnershipType? ownership;

  /// Product status label: New / Used / Damaged / Returned ...
  final String condition;
  final StockState currentStatus;
  final DateTime? soldDate;
  final String? invoiceNumber;
  final double? supplierCost;
  final double? purchasingCost;
  final SupplierPaymentStatus? supplierPaymentStatus;
  final double? supplierPaidAmount;

  String get key => '$productId-$serialNumber';

  @override
  List<Object?> get props => [
    productId,
    brandName,
    modelName,
    serialNumber,
    stockInDateAuto,
    stockInDateManual,
    type,
    location,
    ownership,
    condition,
    currentStatus,
    soldDate,
    invoiceNumber,
    supplierCost,
    purchasingCost,
    supplierPaymentStatus,
    supplierPaidAmount,
  ];
}
