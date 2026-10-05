import 'package:equatable/equatable.dart';

import 'inventory_logic.dart' show MoneyAllocation;

/// Port of React `models/costingCalculator.ts`. All intermediates stay
/// unrounded; only stored outputs are rounded, exactly as the original, so
/// figures match to the cent.
double roundToTwo(double x) =>
    (((x + 2.220446049250313e-16) * 100).roundToDouble()) / 100;

double roundToSix(double x) =>
    (((x + 2.220446049250313e-16) * 1000000).roundToDouble()) / 1000000;

/// One costed model row. `percentage` is a 0–1 ratio (not ×100).
class CostingModel extends Equatable {
  const CostingModel({
    required this.id,
    this.modelName = '',
    this.units = 0,
    this.unitCostUSD = 0,
    this.totalCostUSD = 0,
    this.percentage = 0,
    this.customPerModel = 0,
    this.customPerUnit = 0,
    this.freightPerModel = 0,
    this.freightPerUnit = 0,
    this.unitCostPKR = 0,
    this.totalLandedUnitCost = 0,
    this.totalShipmentValuePKR = 0,
  });

  final String id;
  final String modelName;
  final int units;
  final double unitCostUSD;
  final double totalCostUSD;
  final double percentage;
  final double customPerModel;
  final double customPerUnit;
  final double freightPerModel;
  final double freightPerUnit;

  /// Unit cost in the local currency (USD × rate). The name is React's.
  final double unitCostPKR;

  /// Unit cost + customs/unit + freight/unit.
  final double totalLandedUnitCost;

  /// Landed unit cost × units ("Inventory Value").
  final double totalShipmentValuePKR;

  CostingModel withInputs({
    String? modelName,
    int? units,
    double? unitCostUSD,
  }) => CostingModel(
    id: id,
    modelName: modelName ?? this.modelName,
    units: units ?? this.units,
    unitCostUSD: unitCostUSD ?? this.unitCostUSD,
  );

  @override
  List<Object?> get props => [
    id,
    modelName,
    units,
    unitCostUSD,
    totalCostUSD,
    percentage,
    customPerModel,
    customPerUnit,
    freightPerModel,
    freightPerUnit,
    unitCostPKR,
    totalLandedUnitCost,
    totalShipmentValuePKR,
  ];
}

class BrandSummary extends Equatable {
  const BrandSummary({
    this.totalUnitCostUSD = 0,
    this.shipmentTotalUSD = 0,
    this.consignmentValue = 0,
    this.totalValueOfBrand = 0,
  });

  /// Simple sum of unit costs (not weighted by units), as React.
  final double totalUnitCostUSD;
  final double shipmentTotalUSD;

  /// Shipment total × USD rate.
  final double consignmentValue;

  /// Consignment + customs + freight.
  final double totalValueOfBrand;

  @override
  List<Object?> get props => [
    totalUnitCostUSD,
    shipmentTotalUSD,
    consignmentValue,
    totalValueOfBrand,
  ];
}

abstract final class CostingCalculator {
  /// Recomputes every model row. Customs and freight are shared out by each
  /// model's share of the shipment's USD value.
  static List<CostingModel> recalculateAll(
    List<CostingModel> models, {
    required double usdRate,
    required double totalCustoms,
    required double totalFreight,
  }) {
    final weights = [for (final m in models) m.units * m.unitCostUSD];
    final shipment = weights.fold<double>(0, (s, w) => s + w);
    // Owner decision 8: remainder-correct, so per-model customs/freight add
    // back to the exact totals (React rounds each share on its own).
    final customs = MoneyAllocation.allocate(totalCustoms, weights);
    final freight = MoneyAllocation.allocate(totalFreight, weights);
    return [
      for (var i = 0; i < models.length; i++)
        _calculate(models[i], shipment, usdRate, customs[i], freight[i]),
    ];
  }

  static CostingModel _calculate(
    CostingModel m,
    double shipmentTotalUSD,
    double usdRate,
    double customPerModel,
    double freightPerModel,
  ) {
    final totalCostUSD = m.units * m.unitCostUSD;
    final share = shipmentTotalUSD > 0 ? totalCostUSD / shipmentTotalUSD : 0.0;
    final customPerUnit = m.units > 0 ? customPerModel / m.units : 0.0;
    final freightPerUnit = m.units > 0 ? freightPerModel / m.units : 0.0;
    final unitCostPKR = m.unitCostUSD * usdRate;
    final landed = unitCostPKR + customPerUnit + freightPerUnit;
    return CostingModel(
      id: m.id,
      modelName: m.modelName,
      units: m.units,
      unitCostUSD: m.unitCostUSD,
      totalCostUSD: roundToTwo(totalCostUSD),
      percentage: roundToSix(share),
      customPerModel: customPerModel,
      customPerUnit: roundToTwo(customPerUnit),
      freightPerModel: freightPerModel,
      freightPerUnit: roundToTwo(freightPerUnit),
      unitCostPKR: roundToTwo(unitCostPKR),
      totalLandedUnitCost: roundToTwo(landed),
      // Exact line total, so the lines add up to the shipment value.
      totalShipmentValuePKR: roundToTwo(
        unitCostPKR * m.units + customPerModel + freightPerModel,
      ),
    );
  }

  static BrandSummary summary(
    List<CostingModel> models, {
    required double usdRate,
    required double totalCustoms,
    required double totalFreight,
  }) {
    final shipment = models.fold<double>(
      0,
      (s, m) => s + m.units * m.unitCostUSD,
    );
    final consignment = shipment * usdRate;
    return BrandSummary(
      totalUnitCostUSD: roundToTwo(
        models.fold<double>(0, (s, m) => s + m.unitCostUSD),
      ),
      shipmentTotalUSD: roundToTwo(shipment),
      consignmentValue: roundToTwo(consignment),
      totalValueOfBrand: roundToTwo(consignment + totalCustoms + totalFreight),
    );
  }
}
