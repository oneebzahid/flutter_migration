import 'package:bullion_erp/features/accounts/inventory/domain/rules/costing_calculator.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/inventory_logic.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product_transfer.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/transfer_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity + approved-rule tests (docs/BUSINESS_LOGIC_REVIEW.md). Vectors come
/// from the React audit; "DEVIATION" marks owner-approved differences.
void main() {
  group('MoneyAllocation (remainder-correct)', () {
    test('parts always add back to the exact total', () {
      final parts = MoneyAllocation.allocate(100, [1, 1, 1]);
      expect(parts, [33.34, 33.33, 33.33]);
      expect(parts.fold<double>(0, (s, p) => s + p), closeTo(100, 1e-9));
    });
    test('zero weights or zero total give zeros (no NaN)', () {
      expect(MoneyAllocation.allocate(50, [0, 0]), [0, 0]);
      expect(MoneyAllocation.allocate(0, [1, 2]), [0, 0]);
      expect(MoneyAllocation.allocate(10, []), isEmpty);
    });
    test('large values and uneven weights still reconcile', () {
      final w = [3.0, 7.0, 1.0, 13.0];
      final parts = MoneyAllocation.allocate(123456789.99, w);
      expect(
        (parts.fold<double>(0, (s, p) => s + p) * 100).round(),
        12345678999,
      );
    });
  });

  group('Landed cost parity (vector 1)', () {
    CostingModel m(String id, int units, double usd) =>
        CostingModel(id: id, units: units, unitCostUSD: usd);
    test('A 10x\$100, B 5x\$200, rate 280, customs 1000, freight 500', () {
      final models = [m('A', 10, 100), m('B', 5, 200)];
      final r = CostingCalculator.recalculateAll(
        models,
        usdRate: 280,
        totalCustoms: 1000,
        totalFreight: 500,
      );
      expect(r[0].totalLandedUnitCost, 28075);
      expect(r[1].totalLandedUnitCost, 56150);
      expect(r[0].totalShipmentValuePKR, 280750);
      expect(r[1].totalShipmentValuePKR, 280750);
      final s = CostingCalculator.summary(
        models,
        usdRate: 280,
        totalCustoms: 1000,
        totalFreight: 500,
      );
      expect(s.consignmentValue, 560000);
      expect(s.totalValueOfBrand, 561500);
    });
    test('DEVIATION: customs split of 100 over 3 equal models adds to 100', () {
      final r = CostingCalculator.recalculateAll(
        [
          const CostingModel(id: 'a', units: 1, unitCostUSD: 10),
          const CostingModel(id: 'b', units: 1, unitCostUSD: 10),
          const CostingModel(id: 'c', units: 1, unitCostUSD: 10),
        ],
        usdRate: 1,
        totalCustoms: 100,
        totalFreight: 0,
      );
      final sum = r.fold<double>(0, (s, x) => s + x.customPerModel);
      expect(sum, closeTo(100, 1e-9)); // React: 33.33 x 3 = 99.99
    });
    test('rounding vector 2: 3 units, \$10, customs 100 -> total 130.00', () {
      final r = CostingCalculator.recalculateAll(
        [const CostingModel(id: 'a', units: 3, unitCostUSD: 10)],
        usdRate: 1,
        totalCustoms: 100,
        totalFreight: 0,
      );
      expect(r.single.customPerUnit, 33.33);
      expect(r.single.totalLandedUnitCost, 43.33);
      expect(r.single.totalShipmentValuePKR, 130.00);
    });
    test('degenerate: zero units / zero shipment never produce NaN', () {
      final r = CostingCalculator.recalculateAll(
        [const CostingModel(id: 'a', units: 0, unitCostUSD: 0)],
        usdRate: 3.67,
        totalCustoms: 100,
        totalFreight: 100,
      );
      expect(r.single.customPerUnit, 0);
      expect(r.single.totalLandedUnitCost, 0);
    });
  });

  group('Stock is derived from Available serials (decision 1)', () {
    test('sold / in-transit / damaged serials are not on hand', () {
      final n = StockValuation.onHand(
        ['a', 'b', 'c', 'd', 'e'],
        {
          'a': SerialStatus.available,
          'b': SerialStatus.sold,
          'c': SerialStatus.inTransit,
          'd': SerialStatus.damaged,
          // e: no status recorded -> Available
        },
      );
      expect(n, 2);
    });
    test('returning a sold unit (status back to Available) restores stock', () {
      const sold = {'a': SerialStatus.sold, 'b': SerialStatus.available};
      expect(StockValuation.onHand(['a', 'b'], sold), 1);
      final back = {...sold, 'a': SerialStatus.available};
      expect(StockValuation.onHand(['a', 'b'], back), 2);
    });
  });

  group('Average cost over Available units only (decision 2)', () {
    test('3 on hand @100 + 2 @130 -> 112.00 (React incl. sold: 110.00)', () {
      expect(
        StockValuation.weightedAverageCost(
          availableQty: 3,
          availableCost: 100,
          newQty: 2,
          newCost: 130,
        ),
        112.00,
      );
    });
    test('nothing on hand -> new cost; zero quantities are safe', () {
      expect(
        StockValuation.weightedAverageCost(
          availableQty: 0,
          availableCost: 999,
          newQty: 2,
          newCost: 130,
        ),
        130,
      );
      expect(
        StockValuation.weightedAverageCost(
          availableQty: 0,
          availableCost: 0,
          newQty: 0,
          newCost: 0,
        ),
        0,
      );
    });
  });

  group('Sell price only ever raised (decision 3)', () {
    test('lower incoming price is ignored, higher one applies', () {
      expect(StockValuation.raiseOnlySellPrice(125, 100), 125);
      expect(StockValuation.raiseOnlySellPrice(125, 150), 150);
      expect(StockValuation.raiseOnlySellPrice(125, 125), 125);
    });
  });

  group('Supplier payment guards (decision 5)', () {
    test('cost 1000: pay 400 -> partial, then 600 -> cleared', () {
      expect(
        SupplierPaymentRules.validate(cost: 1000, paid: 0, amount: 400),
        isNull,
      );
      expect(
        SupplierPaymentRules.status(cost: 1000, paid: 400),
        SupplierPaymentStatus.partial,
      );
      expect(
        SupplierPaymentRules.validate(cost: 1000, paid: 400, amount: 600),
        isNull,
      );
      expect(
        SupplierPaymentRules.status(cost: 1000, paid: 1000),
        SupplierPaymentStatus.cleared,
      );
    });
    test('overpayment is rejected (React stored 1500 on a 1000 cost)', () {
      expect(
        SupplierPaymentRules.validate(cost: 1000, paid: 0, amount: 1500),
        contains('exceeds the outstanding balance'),
      );
      expect(
        SupplierPaymentRules.validate(cost: 1000, paid: 900, amount: 100.01),
        isNotNull,
      );
    });
    test('missing / zero cost is never Cleared and blocks payment', () {
      for (final c in [null, 0.0, -5.0]) {
        expect(
          SupplierPaymentRules.validate(cost: c, paid: 0, amount: 10),
          contains('cost is required'),
        );
        expect(
          SupplierPaymentRules.status(cost: c, paid: 10),
          SupplierPaymentStatus.unpaid,
        );
      }
    });
    test('zero / negative amounts are rejected', () {
      expect(
        SupplierPaymentRules.validate(cost: 100, paid: 0, amount: 0),
        isNotNull,
      );
      expect(
        SupplierPaymentRules.validate(cost: 100, paid: 0, amount: -1),
        isNotNull,
      );
    });
  });

  group('Late-charge remaining cost (never silently 0)', () {
    test(
      'qty 20, landed 2000, 19 stocked @100 -> 100.00; +100 charge -> 200',
      () {
        final a = RemainingLayerCost.compute(
          landedTotal: 2000,
          stockedValue: 1900,
          remainingUnits: 1,
        );
        expect(a.unitCost, 100);
        final b = RemainingLayerCost.compute(
          landedTotal: 2100,
          stockedValue: 1900,
          remainingUnits: 1,
        );
        expect(b.unitCost, 200);
      },
    );
    test('credit pushing total below stocked value is an error, not 0', () {
      final c = RemainingLayerCost.compute(
        landedTotal: 1800,
        stockedValue: 1900,
        remainingUnits: 1,
      );
      expect(c.unitCost, isNull);
      expect(c.error, isNotNull);
    });
  });

  group('Serial uniqueness', () {
    test('trimmed and case-insensitive', () {
      expect(normalizeSerial('  sn-1 '), normalizeSerial('SN-1'));
    });
  });

  group('Transfer rules (decision 4)', () {
    const l1 = TransferLine(productId: 'a', serials: ['1', '2'], unitValue: 10);
    const l2 = TransferLine(productId: 'b', serials: ['3'], unitValue: 10);
    test('validation order and messages', () {
      expect(
        TransferRules.validate(
          transferredBy: '',
          from: 'X',
          to: 'Y',
          lines: [l1],
        ),
        'Enter who is transferring.',
      );
      expect(
        TransferRules.validate(
          transferredBy: 'A',
          from: 'X',
          to: 'x',
          lines: [l1],
        ),
        'Source and destination must be different.',
      );
      expect(
        TransferRules.validate(
          transferredBy: 'A',
          from: 'X',
          to: 'Y',
          lines: const [],
        ),
        'Select at least one serial to transfer.',
      );
      expect(
        TransferRules.validate(
          transferredBy: 'A',
          from: 'X',
          to: 'Y',
          lines: [l1],
        ),
        isNull,
      );
    });
    test('freight 90 split by value (20 : 10) = 60 + 30, exact', () {
      final parts = TransferRules.splitFreight(90, [l1, l2]);
      expect(parts, [60, 30]);
    });
    test(
      'freight 100 over 3 equal lines adds to 100 (React stored 100 x 3)',
      () {
        const l = TransferLine(productId: 'x', serials: ['1'], unitValue: 5);
        final parts = TransferRules.splitFreight(100, [l, l, l]);
        expect(parts.fold<double>(0, (s, p) => s + p), closeTo(100, 1e-9));
      },
    );
    test('no unit values -> split by quantity', () {
      const a = TransferLine(productId: 'a', serials: ['1', '2', '3']);
      const b = TransferLine(productId: 'b', serials: ['4']);
      expect(TransferRules.splitFreight(40, [a, b]), [30, 10]);
    });
  });
}
