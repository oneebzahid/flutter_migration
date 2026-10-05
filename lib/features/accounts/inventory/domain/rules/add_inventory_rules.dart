import 'costing_calculator.dart';

/// Default margin when stocking in from a shipment (React `DEFAULT_MARGIN_PERCENT`).
const double kDefaultMarginPercent = 25;

/// React `suggestedSellPrice(landed, margin) = round2(landed × (1 + margin/100))`.
double suggestedSellPrice(double landedUnitCost, double marginPercent) {
  final m = marginPercent.isNaN ? 0.0 : marginPercent;
  return roundToTwo(landedUnitCost * (1 + m / 100));
}

/// The plain data of one entry row, as the validator needs it.
class EntryRowData {
  const EntryRowData({
    required this.brand,
    required this.model,
    required this.category,
    required this.quantity,
    required this.costPrice,
    required this.sellPrice,
    required this.serials,
    required this.location,
    this.hasShipment = false,
    this.manualModelInShipment = false,
    this.lineRemaining,
  });

  final String brand;
  final String model;
  final String category;
  final int quantity;
  final double costPrice;
  final double sellPrice;
  final List<String> serials;
  final String location;

  /// The row belongs to a picked shipment.
  final bool hasShipment;

  /// "New model on this shipment (not on the list)".
  final bool manualModelInShipment;

  /// Units left on the chosen shipment line; null when no line is chosen.
  final int? lineRemaining;

  List<String> get filledSerials => [
    for (final s in serials)
      if (s.trim().isNotEmpty) s.trim(),
  ];

  /// Units being stocked: filled serials, else the typed quantity.
  int get wanted => filledSerials.isEmpty ? quantity : filledSerials.length;
}

class EntryValidation {
  const EntryValidation({
    this.rowErrors = const {},
    this.missingLocation = const [],
  });

  /// row index → field → message. Fields: brand, model, category, cost,
  /// retail, quantity, serials.
  final Map<int, Map<String, String>> rowErrors;

  /// Row indexes without a location (reported as a message, not inline).
  final List<int> missingLocation;

  bool get isValid => rowErrors.isEmpty && missingLocation.isEmpty;

  bool get hasSerialProblem => rowErrors.values.any(
    (e) => e.containsKey('serials') || e.containsKey('quantity'),
  );
}

abstract final class AddInventoryRules {
  static EntryValidation validate(List<EntryRowData> rows) {
    final errors = <int, Map<String, String>>{};
    final noLocation = <int>[];

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final e = <String, String>{};

      if (r.brand.trim().isEmpty) e['brand'] = 'Required';
      if (r.model.trim().isEmpty) {
        e['model'] =
            r.hasShipment && !r.manualModelInShipment && r.lineRemaining == null
            ? 'Pick a model'
            : 'Required';
      }
      if (r.category.trim().isEmpty) e['category'] = 'Required';

      if (r.lineRemaining != null && r.wanted > r.lineRemaining!) {
        e['cost'] = 'Only ${r.lineRemaining} unit(s) remain on this line';
      }
      // "Required" deliberately overwrites the remaining-units message (React).
      if (r.costPrice <= 0) e['cost'] = 'Required';

      if (r.sellPrice <= 0) {
        e['retail'] = 'Required';
      } else if (r.costPrice > 0 && r.sellPrice < r.costPrice) {
        e['retail'] =
            'Retail cannot be below the cost of ${r.costPrice.toStringAsFixed(2)}';
      }

      if (r.quantity <= 0) {
        e['quantity'] = 'Must be at least 1';
      } else {
        final filled = r.filledSerials;
        if (filled.isEmpty) {
          e['serials'] = 'Serial numbers are required';
        } else if (filled.length != r.quantity) {
          e['serials'] =
              'Provide ${r.quantity} serial${r.quantity == 1 ? '' : 's'} (${filled.length} filled)';
        } else if (filled.toSet().length != filled.length) {
          e['serials'] = 'Duplicate serial numbers';
        }
      }

      if (e.isNotEmpty) errors[i] = e;
      if (r.location.trim().isEmpty) noLocation.add(i);
    }
    return EntryValidation(rowErrors: errors, missingLocation: noLocation);
  }

  /// Σ cost × (filled serials or quantity) — the "Grand Total" bar.
  static double grandTotal(List<EntryRowData> rows) =>
      rows.fold(0.0, (s, r) => s + r.costPrice * r.wanted);
}
