import '../entities/product.dart';
import '../entities/product_transfer.dart';
import 'inventory_logic.dart';

/// Create-form validation, freight split and eligibility rules for transfers
/// (owner decision 4). Pure Dart.
abstract final class TransferRules {
  /// Create-form validation, in React's order. Null = valid.
  static String? validate({
    required String transferredBy,
    required String from,
    required String to,
    required List<TransferLine> lines,
    double shipmentCost = 0,
  }) {
    if (transferredBy.trim().isEmpty) return 'Enter who is transferring.';
    if (from.isEmpty) return 'Select the source location.';
    if (to.isEmpty) return 'Select the destination location.';
    if (from.toLowerCase() == to.toLowerCase()) {
      return 'Source and destination must be different.';
    }
    if (lines.isEmpty || lines.every((l) => l.serials.isEmpty)) {
      return 'Select at least one serial to transfer.';
    }
    if (shipmentCost < 0) return 'Shipment cost cannot be negative.';
    return null;
  }

  /// Freight split by value (owner decision 4): each line's share follows
  /// unitValue x quantity (falls back to quantity when no values are known),
  /// remainder-correct so the shares add up to exactly [total].
  static List<double> splitFreight(double total, List<TransferLine> lines) {
    final byValue = [for (final l in lines) l.unitValue * l.serials.length];
    final weights = byValue.every((v) => v <= 0)
        ? [for (final l in lines) l.serials.length.toDouble()]
        : byValue;
    return MoneyAllocation.allocate(total, weights);
  }

  /// A serial can be offered for transfer only when it is at [from], is
  /// Available/Returned, and is not held by another open transfer.
  static bool eligible({
    required String serial,
    required Product product,
    required String from,
    required Set<String> reservedSerials,
  }) {
    final status = product.serialStatus[serial] ?? SerialStatus.available;
    if (status != SerialStatus.available && status != SerialStatus.returned) {
      return false;
    }
    final city = product.serialCities[serial] ?? product.location ?? '';
    if (city.toLowerCase() != from.toLowerCase()) return false;
    return !reservedSerials.contains(normalizeSerial(serial));
  }

  /// Serials that block a receive (not In Transit any more / gone).
  static List<String> notInTransit(Product product, List<String> serials) => [
    for (final s in serials)
      if (!product.serialNumbers.contains(s) ||
          product.serialStatus[s] != SerialStatus.inTransit)
        s,
  ];
}
