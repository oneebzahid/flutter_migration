import 'package:equatable/equatable.dart';

import '../entities/inventory_report_row.dart';
import '../entities/product.dart';

const Object _keep = Object();

/// Dashboard filters (React `useInventoryReportViewModel`). AND across groups,
/// OR within a group; an empty selection means "no filter".
class ReportFilters extends Equatable {
  const ReportFilters({
    this.search = '',
    this.brands = const {},
    this.models = const {},
    this.types = const {},
    this.locations = const {},
    this.conditions = const {},
    this.statuses = const {},
    this.ownerships = const {},
    this.dateFrom,
    this.dateTo,
  });

  final String search;
  final Set<String> brands;
  final Set<String> models;
  final Set<String> types;
  final Set<String> locations;
  final Set<String> conditions;
  final Set<String> statuses;
  final Set<String> ownerships;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  static const empty = ReportFilters();

  static const conditionOptions = ['New', 'Used'];
  static final statusOptions = [for (final s in StockState.values) s.label];
  static final ownershipOptions = [
    for (final o in OwnershipType.values) o.label,
  ];

  ReportFilters copyWith({
    String? search,
    Set<String>? brands,
    Set<String>? models,
    Set<String>? types,
    Set<String>? locations,
    Set<String>? conditions,
    Set<String>? statuses,
    Set<String>? ownerships,
    Object? dateFrom = _keep,
    Object? dateTo = _keep,
  }) => ReportFilters(
    search: search ?? this.search,
    brands: brands ?? this.brands,
    models: models ?? this.models,
    types: types ?? this.types,
    locations: locations ?? this.locations,
    conditions: conditions ?? this.conditions,
    statuses: statuses ?? this.statuses,
    ownerships: ownerships ?? this.ownerships,
    dateFrom: identical(dateFrom, _keep)
        ? this.dateFrom
        : dateFrom as DateTime?,
    dateTo: identical(dateTo, _keep) ? this.dateTo : dateTo as DateTime?,
  );

  /// Search box is not counted (as in React).
  int get activeCount => [
    brands.isNotEmpty,
    models.isNotEmpty,
    types.isNotEmpty,
    locations.isNotEmpty,
    conditions.isNotEmpty,
    statuses.isNotEmpty,
    ownerships.isNotEmpty,
    dateFrom != null,
    dateTo != null,
  ].where((b) => b).length;

  bool matches(InventoryReportRow r) {
    if (search.isNotEmpty) {
      final hay = [
        r.brandName,
        r.modelName,
        r.serialNumber,
        r.type,
        r.location,
        r.ownership?.label,
        r.condition,
        r.currentStatus.label,
        r.invoiceNumber,
        r.supplierPaymentStatus?.label,
      ].whereType<String>().join(' ').toLowerCase();
      if (!hay.contains(search.toLowerCase())) return false;
    }
    bool inSet(Set<String> s, String? v) =>
        s.isEmpty || (v != null && s.contains(v));
    if (!inSet(brands, r.brandName) ||
        !inSet(models, r.modelName) ||
        !inSet(types, r.type) ||
        !inSet(locations, r.location) ||
        !inSet(conditions, r.condition) ||
        !inSet(statuses, r.currentStatus.label) ||
        !inSet(ownerships, r.ownership?.label ?? 'Owned')) {
      return false;
    }
    // Date range on the auto stock-in date; "to" is inclusive to end of day.
    final d = r.stockInDateAuto;
    if (dateFrom != null && (d == null || d.isBefore(dateFrom!))) return false;
    if (dateTo != null) {
      final end = DateTime(
        dateTo!.year,
        dateTo!.month,
        dateTo!.day,
        23,
        59,
        59,
        999,
      );
      if (d == null || d.isAfter(end)) return false;
    }
    return true;
  }

  /// Filtered rows sorted by stock-in date (newest first, undated last),
  /// ties by brand|model|serial.
  List<InventoryReportRow> apply(List<InventoryReportRow> rows) {
    final out = rows.where(matches).toList();
    out.sort((a, b) {
      final da = a.stockInDateAuto, db = b.stockInDateAuto;
      if (da != null && db != null) {
        final c = db.compareTo(da);
        if (c != 0) return c;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      return '${a.brandName}|${a.modelName}|${a.serialNumber}'.compareTo(
        '${b.brandName}|${b.modelName}|${b.serialNumber}',
      );
    });
    return out;
  }

  @override
  List<Object?> get props => [
    search,
    brands,
    models,
    types,
    locations,
    conditions,
    statuses,
    ownerships,
    dateFrom,
    dateTo,
  ];
}

List<String> distinctSorted(Iterable<String> values) =>
    (values.where((v) => v.isNotEmpty).toSet().toList()..sort());
