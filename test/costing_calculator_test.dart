import 'package:bullion_erp/features/accounts/inventory/domain/rules/costing_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

CostingModel _m(String id, int units, double cost) =>
    CostingModel(id: id, modelName: id, units: units, unitCostUSD: cost);

void main() {
  // Worked examples computed by hand from the React costingCalculator.ts.
  test('example 1: clean numbers', () {
    final r = CostingCalculator.recalculateAll(
      [_m('A', 10, 100), _m('B', 5, 200)],
      usdRate: 280,
      totalCustoms: 10000,
      totalFreight: 5000,
    );
    final a = r[0], b = r[1];
    expect(a.totalCostUSD, 1000);
    expect(a.percentage, 0.5);
    expect(a.customPerModel, 5000);
    expect(a.customPerUnit, 500);
    expect(a.freightPerModel, 2500);
    expect(a.freightPerUnit, 250);
    expect(a.unitCostPKR, 28000);
    expect(a.totalLandedUnitCost, 28750);
    expect(a.totalShipmentValuePKR, 287500);
    expect(b.customPerUnit, 1000);
    expect(b.freightPerUnit, 500);
    expect(b.unitCostPKR, 56000);
    expect(b.totalLandedUnitCost, 57500);
    expect(b.totalShipmentValuePKR, 287500);

    final s = CostingCalculator.summary(
      [_m('A', 10, 100), _m('B', 5, 200)],
      usdRate: 280,
      totalCustoms: 10000,
      totalFreight: 5000,
    );
    expect(s.totalUnitCostUSD, 300);
    expect(s.shipmentTotalUSD, 2000);
    expect(s.consignmentValue, 560000);
    expect(s.totalValueOfBrand, 575000);
  });

  test('example 2: three models, rounding visible', () {
    final models = [_m('A', 3, 150), _m('B', 7, 20), _m('C', 1, 100)];
    final r = CostingCalculator.recalculateAll(
      models,
      usdRate: 3.67,
      totalCustoms: 500,
      totalFreight: 250,
    );
    expect(r[0].totalCostUSD, 450);
    expect(r[0].percentage, 0.652174);
    expect(r[0].customPerModel, 326.09);
    expect(r[0].customPerUnit, 108.70);
    expect(r[0].freightPerModel, 163.04);
    expect(r[0].freightPerUnit, 54.35);
    expect(r[0].unitCostPKR, 550.50);
    expect(r[0].totalLandedUnitCost, 713.54);
    expect(r[0].totalShipmentValuePKR, 2140.63);

    expect(r[1].percentage, 0.202899);
    expect(r[1].customPerModel, 101.45);
    expect(r[1].customPerUnit, 14.49);
    expect(r[1].freightPerUnit, 7.25);
    expect(r[1].unitCostPKR, 73.40);
    expect(r[1].totalLandedUnitCost, 95.14);
    // Remainder-correct (owner decision 8): line total is exact, 665.98 (React 665.97).
    expect(r[1].totalShipmentValuePKR, 665.98);

    expect(r[2].percentage, 0.144928);
    expect(r[2].customPerModel, 72.46);
    expect(
      r[2].totalLandedUnitCost,
      475.69,
    ); // React 475.70 (1c, remainder-correct)
    // Remainder-correct: 475.69 (React 475.70). Lines now add up exactly.
    expect(r[2].totalShipmentValuePKR, 475.69);

    // The rounded ratios do not sum to exactly 1 (React shows 1.000001).
    final sum = r.fold<double>(0, (s, m) => s + m.percentage);
    expect(roundToSix(sum), 1.000001);

    final s = CostingCalculator.summary(
      models,
      usdRate: 3.67,
      totalCustoms: 500,
      totalFreight: 250,
    );
    expect(s.totalUnitCostUSD, 270);
    expect(s.shipmentTotalUSD, 690);
    expect(s.consignmentValue, 2532.30);
    expect(s.totalValueOfBrand, 3282.30);
  });

  test('example 3: a row with zero units does not divide by zero', () {
    final models = [_m('A', 4, 25), _m('B', 0, 30)];
    final r = CostingCalculator.recalculateAll(
      models,
      usdRate: 280,
      totalCustoms: 1000,
      totalFreight: 0,
    );
    expect(r[0].percentage, 1);
    expect(r[0].customPerModel, 1000);
    expect(r[0].customPerUnit, 250);
    expect(r[0].unitCostPKR, 7000);
    expect(r[0].totalLandedUnitCost, 7250);
    expect(r[0].totalShipmentValuePKR, 29000);
    expect(r[1].percentage, 0);
    expect(r[1].customPerUnit, 0);
    expect(r[1].unitCostPKR, 8400);
    expect(r[1].totalLandedUnitCost, 8400);
    expect(r[1].totalShipmentValuePKR, 0);

    final s = CostingCalculator.summary(
      models,
      usdRate: 280,
      totalCustoms: 1000,
      totalFreight: 0,
    );
    expect(s.totalUnitCostUSD, 55); // simple sum, not unit-weighted
    expect(s.shipmentTotalUSD, 100);
    expect(s.consignmentValue, 28000);
    expect(s.totalValueOfBrand, 29000);
  });

  test('edge cases: zero rate and zero shipment', () {
    final zeroRate = CostingCalculator.recalculateAll(
      [_m('A', 2, 10)],
      usdRate: 0,
      totalCustoms: 0,
      totalFreight: 0,
    );
    expect(zeroRate.single.unitCostPKR, 0);

    final empty = CostingCalculator.recalculateAll(
      [_m('A', 0, 0)],
      usdRate: 3,
      totalCustoms: 100,
      totalFreight: 100,
    );
    expect(empty.single.percentage, 0); // customs/freight are not distributed
    expect(empty.single.customPerModel, 0);
    expect(
      CostingCalculator.recalculateAll(
        [],
        usdRate: 1,
        totalCustoms: 1,
        totalFreight: 1,
      ),
      isEmpty,
    );
  });
}
