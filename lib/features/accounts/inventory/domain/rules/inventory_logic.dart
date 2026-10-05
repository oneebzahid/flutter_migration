import 'costing_calculator.dart' show roundToTwo;
import '../entities/product.dart';

/// Pure business rules approved by the owner (docs/BUSINESS_LOGIC_REVIEW.md).
/// No UI, database or framework imports: the same code backs the mock
/// repository today and the Supabase repository later.

/// Serial identity: trimmed, case-insensitive (owner decision 6).
String normalizeSerial(String s) => s.trim().toUpperCase();

/// Remainder-correct allocation (owner decision 8, deviation from React).
abstract final class MoneyAllocation {
  /// Splits [total] across [weights] in whole cents using the largest
  /// remainder method, so the parts always add back to exactly [total].
  /// React rounds each share independently and can drift by a cent or more.
  static List<double> allocate(double total, List<double> weights) {
    if (weights.isEmpty) return const [];
    final sum = weights.fold<double>(0, (s, w) => s + w);
    if (sum <= 0 || total == 0) return List.filled(weights.length, 0);
    final cents = (total * 100).round();
    final raw = [for (final w in weights) cents * w / sum];
    final floors = [for (final r in raw) r.floor()];
    var left = cents - floors.fold<int>(0, (s, f) => s + f);
    final order = List<int>.generate(weights.length, (i) => i)
      ..sort((a, b) {
        final c = (raw[b] - floors[b]).compareTo(raw[a] - floors[a]);
        return c != 0 ? c : a.compareTo(b);
      });
    for (var k = 0; left > 0; k = (k + 1) % order.length, left--) {
      floors[order[k]]++;
    }
    return [for (final f in floors) f / 100];
  }
}

abstract final class StockValuation {
  /// Count of units that are actually on hand: serials whose status is
  /// Available (a serial with no recorded status counts as Available).
  static int onHand(List<String> serials, Map<String, SerialStatus> status) {
    var n = 0;
    for (final s in serials) {
      if ((status[s] ?? SerialStatus.available) == SerialStatus.available) n++;
    }
    return n;
  }

  /// Weighted average over AVAILABLE units only (owner decision 2).
  /// 3 on hand @100 + 2 new @130 -> 112.00 (React, counting a sold unit: 110.00).
  static double weightedAverageCost({
    required int availableQty,
    required double availableCost,
    required int newQty,
    required double newCost,
  }) {
    final total = availableQty + newQty;
    if (total <= 0) return roundToTwo(newCost);
    return roundToTwo(
      (availableQty * availableCost + newQty * newCost) / total,
    );
  }

  /// A stock-in never lowers a price (owner decision 3).
  static double raiseOnlySellPrice(double current, double incoming) =>
      incoming > current ? incoming : current;
}

/// Cost of the units still to be stocked on a shipment line. Owner decision:
/// never silently turn a negative balance into a free unit.
class RemainingLayerCost {
  const RemainingLayerCost._(this.unitCost, this.error);
  final double? unitCost;
  final String? error;

  static RemainingLayerCost compute({
    required double landedTotal,
    required double stockedValue,
    required int remainingUnits,
  }) {
    if (remainingUnits <= 0) return const RemainingLayerCost._(0, null);
    final left = landedTotal - stockedValue;
    if (left < 0) {
      return RemainingLayerCost._(
        null,
        'Already-stocked value (${roundToTwo(stockedValue)}) exceeds the '
        'shipment landed total (${roundToTwo(landedTotal)}). Review the '
        'charges before stocking the remaining units.',
      );
    }
    return RemainingLayerCost._(roundToTwo(left / remainingUnits), null);
  }
}

/// Supplier payment guards (owner decision 5).
abstract final class SupplierPaymentRules {
  static const _eps = 0.005;

  static double outstanding(double? cost, double paid) =>
      ((cost ?? 0) - paid).clamp(0, double.infinity).toDouble();

  /// Null when the payment may be recorded, otherwise the message to show.
  static String? validate({
    required double? cost,
    required double paid,
    required double amount,
  }) {
    if (cost == null || cost <= 0) {
      return 'A supplier cost is required before a payment can be recorded.';
    }
    if (amount <= 0) return 'Enter a payment amount greater than zero.';
    final remaining = cost - paid;
    if (amount > remaining + _eps) {
      return 'Payment exceeds the outstanding balance '
          '(${roundToTwo(remaining < 0 ? 0 : remaining)}).';
    }
    return null;
  }

  /// Cleared only when a positive cost has been fully paid.
  static SupplierPaymentStatus status({
    required double? cost,
    required double paid,
  }) {
    if (cost == null || cost <= 0 || paid <= 0) {
      return SupplierPaymentStatus.unpaid;
    }
    return paid + _eps >= cost
        ? SupplierPaymentStatus.cleared
        : SupplierPaymentStatus.partial;
  }
}
