/// Validation for "Add to Existing Inventory", with the messages React shows.
/// Pure functions so they are easy to test and reuse.
abstract final class AddStockRules {
  /// Serial inputs with blanks removed. React saves them untrimmed; we trim,
  /// otherwise "SN1" and "SN1 " would count as different serials.
  static List<String> filled(List<String> inputs) => [
    for (final s in inputs)
      if (s.trim().isNotEmpty) s.trim(),
  ];

  /// Distinct values that appear more than once.
  static List<String> duplicates(List<String> values) {
    final seen = <String>{};
    final dup = <String>{};
    for (final v in values) {
      if (!seen.add(v)) dup.add(v);
    }
    return dup.toList();
  }

  /// The first problem found, in React's order, or null when valid:
  /// count mismatch → duplicates inside the batch → duplicates of the
  /// product's own existing serials. (Clashes with OTHER products are checked
  /// against the backend afterwards.)
  static String? validate({
    required int quantity,
    required List<String> serialInputs,
    required Iterable<String> existingOnProduct,
  }) {
    final serials = filled(serialInputs);
    if (serials.length != quantity) {
      return 'Please provide $quantity serial number${quantity > 1 ? 's' : ''}';
    }
    final batch = duplicates(serials);
    if (batch.isNotEmpty) {
      return 'Duplicate serial${batch.length > 1 ? 's' : ''} in the new batch: ${batch.join(', ')}';
    }
    final existing = existingOnProduct.toSet();
    final clash = [
      for (final s in serials)
        if (existing.contains(s)) s,
    ];
    if (clash.isNotEmpty) {
      return 'Duplicate serial${clash.length > 1 ? 's' : ''}: ${clash.join(', ')}';
    }
    return null;
  }

  /// React: an empty / non-numeric quantity counts as 1.
  static int parseQuantity(String text) {
    final n = int.tryParse(text.trim()) ?? 1;
    return n < 1 ? 1 : n;
  }

  /// React: empty, non-numeric or negative price input becomes 0.
  static double parsePrice(String text) {
    final n = double.tryParse(text.trim().replaceAll(',', '')) ?? 0;
    return n < 0 ? 0 : n;
  }
}
