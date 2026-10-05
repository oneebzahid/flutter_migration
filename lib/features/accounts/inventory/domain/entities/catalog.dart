import 'package:equatable/equatable.dart';

import 'product.dart';

/// A model under a brand, with the values last used for it (React brand/model
/// profile): selecting it pre-fills blank fields on the entry form.
class ModelOption extends Equatable {
  const ModelOption({
    required this.id,
    required this.name,
    this.costPrice,
    this.sellPrice,
    this.category = '',
    this.description = '',
    this.location = '',
  });

  final String id;
  final String name;
  final double? costPrice;
  final double? sellPrice;
  final String category;
  final String description;
  final String location;

  @override
  List<Object?> get props => [
    id,
    name,
    costPrice,
    sellPrice,
    category,
    description,
    location,
  ];
}

/// One stockable line of a purchase shipment, with its landed cost per unit.
class StockInLine extends Equatable {
  const StockInLine({
    required this.lineId,
    required this.modelName,
    required this.remaining,
    required this.landedUnitCost,
    this.stocked = 0,
    this.goodsPerUnit = 0,
    this.customsPerUnit = 0,
    this.freightPerUnit = 0,
    this.taxPerUnit = 0,
    this.otherPerUnit = 0,
  });

  final String lineId;
  final String modelName;

  /// Units not yet stocked in.
  final int remaining;

  /// Units already stocked in (their cost may be lower than today's).
  final int stocked;
  final double landedUnitCost;
  final double goodsPerUnit;
  final double customsPerUnit;
  final double freightPerUnit;
  final double taxPerUnit;
  final double otherPerUnit;

  @override
  List<Object?> get props => [
    lineId,
    modelName,
    remaining,
    stocked,
    landedUnitCost,
    goodsPerUnit,
    customsPerUnit,
    freightPerUnit,
    taxPerUnit,
    otherPerUnit,
  ];
}

class Shipment extends Equatable {
  const Shipment({
    required this.id,
    required this.number,
    required this.brandName,
    required this.supplierName,
    required this.lines,
  });

  final String id;
  final String number;
  final String brandName;
  final String supplierName;
  final List<StockInLine> lines;

  /// "SHP-001 · Nokta · ABC Trading" (dropdown label).
  String get label => '$number · $brandName · $supplierName';

  @override
  List<Object?> get props => [id, number, brandName, supplierName, lines];
}

/// Everything needed to create one product from the entry form.
class NewProductDraft extends Equatable {
  const NewProductDraft({
    required this.brandName,
    required this.modelName,
    required this.category,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    required this.location,
    required this.serials,
    required this.ownership,
    this.description = '',
    this.status = ProductStatus.newItem,
    this.buyType = BuyType.import,
    this.warrantyYears = 0,
    this.stockInDateManual,
    this.shipmentId,
    this.shipmentLineId,
    this.imageCount = 0,
  });

  final String brandName;
  final String modelName;
  final String category;
  final String description;
  final double costPrice;
  final double sellPrice;

  /// Typed quantity; the saved stock is the number of non-empty serials.
  final int quantity;
  final String location;
  final List<String> serials;
  final OwnershipType ownership;
  final ProductStatus status;
  final BuyType buyType;
  final int warrantyYears;
  final DateTime? stockInDateManual;
  final String? shipmentId;
  final String? shipmentLineId;
  final int imageCount;

  List<String> get filledSerials => [
    for (final s in serials)
      if (s.trim().isNotEmpty) s.trim(),
  ];

  /// Saved stock = filled serials, else the typed quantity (React).
  int get stock => filledSerials.isEmpty ? quantity : filledSerials.length;

  @override
  List<Object?> get props => [
    brandName,
    modelName,
    category,
    description,
    costPrice,
    sellPrice,
    quantity,
    location,
    serials,
    ownership,
    status,
    buyType,
    warrantyYears,
    stockInDateManual,
    shipmentId,
    shipmentLineId,
    imageCount,
  ];
}
