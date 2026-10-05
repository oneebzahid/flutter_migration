import 'package:equatable/equatable.dart';

import '../entities/product.dart';

/// React `ProductFilters` + `InventoryService.filterProducts` /
/// `calculateProductStats` / `countActiveProductFilters`, ported 1:1.
class ProductFilters extends Equatable {
  const ProductFilters({
    this.brandSearch = '',
    this.modelSearch = '',
    this.category,
    this.status,
    this.buyType,
    this.location,
    this.minPrice,
    this.maxPrice,
    this.hasStock,
  });

  final String brandSearch;
  final String modelSearch;
  final String? category;
  final ProductStatus? status;
  final BuyType? buyType;
  final String? location;
  final double? minPrice;
  final double? maxPrice;

  /// null = any, true = in stock (>0), false = out of stock (==0).
  final bool? hasStock;

  static const empty = ProductFilters();

  ProductFilters copyWith({
    String? brandSearch,
    String? modelSearch,
    Object? category = _keep,
    Object? status = _keep,
    Object? buyType = _keep,
    Object? location = _keep,
    Object? minPrice = _keep,
    Object? maxPrice = _keep,
    Object? hasStock = _keep,
  }) => ProductFilters(
    brandSearch: brandSearch ?? this.brandSearch,
    modelSearch: modelSearch ?? this.modelSearch,
    category: identical(category, _keep) ? this.category : category as String?,
    status: identical(status, _keep) ? this.status : status as ProductStatus?,
    buyType: identical(buyType, _keep) ? this.buyType : buyType as BuyType?,
    location: identical(location, _keep) ? this.location : location as String?,
    minPrice: identical(minPrice, _keep) ? this.minPrice : minPrice as double?,
    maxPrice: identical(maxPrice, _keep) ? this.maxPrice : maxPrice as double?,
    hasStock: identical(hasStock, _keep) ? this.hasStock : hasStock as bool?,
  );

  int get activeCount => [
    brandSearch.isNotEmpty,
    modelSearch.isNotEmpty,
    category != null,
    status != null,
    buyType != null,
    location != null,
    minPrice != null,
    maxPrice != null,
    hasStock != null,
  ].where((b) => b).length;

  bool matches(Product p) {
    bool contains(String hay, String needle) =>
        needle.isEmpty || hay.toLowerCase().contains(needle.toLowerCase());
    return contains(p.brandName, brandSearch) &&
        contains(p.modelName, modelSearch) &&
        (category == null || p.category == category) &&
        (status == null || p.status == status) &&
        (buyType == null || p.buyType == buyType) &&
        (minPrice == null || p.sellPrice >= minPrice!) &&
        (maxPrice == null || p.sellPrice <= maxPrice!) &&
        (hasStock == null || (hasStock! ? p.stock > 0 : p.stock == 0)) &&
        (location == null || p.location == location);
  }

  List<Product> apply(List<Product> products) =>
      products.where(matches).toList();

  @override
  List<Object?> get props => [
    brandSearch,
    modelSearch,
    category,
    status,
    buyType,
    location,
    minPrice,
    maxPrice,
    hasStock,
  ];
}

const Object _keep = Object();

class ProductStats extends Equatable {
  const ProductStats({
    required this.totalProducts,
    required this.totalStock,
    required this.totalValue,
    required this.newProducts,
    required this.inTransit,
    required this.available,
  });

  factory ProductStats.of(List<Product> products) => ProductStats(
    totalProducts: products.length,
    totalStock: products.fold(0, (s, p) => s + p.stock),
    totalValue: products.fold(0.0, (s, p) => s + p.stockValue),
    newProducts: products
        .where((p) => p.status == ProductStatus.newItem)
        .length,
    inTransit: products
        .where((p) => p.status == ProductStatus.inTransit)
        .length,
    available: products
        .where((p) => p.status == ProductStatus.available)
        .length,
  );

  final int totalProducts;
  final int totalStock;
  final double totalValue;
  final int newProducts;
  final int inTransit;
  final int available;

  @override
  List<Object?> get props => [
    totalProducts,
    totalStock,
    totalValue,
    newProducts,
    inTransit,
    available,
  ];
}

List<String> uniqueCategories(List<Product> products) =>
    (products.map((p) => p.category).toSet().toList()..sort());

List<String> uniqueLocations(List<Product> products) =>
    (products
        .map((p) => p.location)
        .whereType<String>()
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort());
