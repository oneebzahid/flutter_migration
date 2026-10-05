import 'package:flutter/material.dart';

import '../../../../../core/widgets/status_badge.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/entities/product.dart';

/// Badge palettes copied from the React inventory screens. Hex values live
/// here (not in feature screens) so a later re-theme touches one file.
abstract final class InventoryBadges {
  static Widget ownership(OwnershipType? o) {
    if (o == null) return const Text('—');
    final credit = o == OwnershipType.credit;
    return StatusBadge(
      label: o.label,
      background: credit ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
      foreground: credit ? const Color(0xFF92400E) : const Color(0xFF334155),
    );
  }

  /// Dashboard "Condition" column (New / Used / Damaged / Returned).
  static Widget condition(String condition) {
    final (bg, fg) = switch (condition) {
      'New' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'Used' => (const Color(0xFFF1F5F9), const Color(0xFF334155)),
      'Damaged' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'Returned' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
    };
    return StatusBadge(label: condition, background: bg, foreground: fg);
  }

  static Widget stockState(StockState s) {
    final sold = s == StockState.sold;
    return StatusBadge(
      label: s.label,
      background: sold ? const Color(0xFFE0E7FF) : const Color(0xFFDCFCE7),
      foreground: sold ? const Color(0xFF4338CA) : const Color(0xFF15803D),
    );
  }

  static Widget payment(SupplierPaymentStatus? s) {
    if (s == null) return const Text('—');
    final (bg, fg) = switch (s) {
      SupplierPaymentStatus.cleared => (
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      SupplierPaymentStatus.partial => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
      SupplierPaymentStatus.unpaid => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
      ),
    };
    return StatusBadge(label: s.label, background: bg, foreground: fg);
  }

  /// List "Condition" column: shows the product status (React `getStatusColor`).
  static Widget productStatus(ProductStatus s) {
    final (bg, fg) = switch (s) {
      ProductStatus.newItem => (
        const Color(0xFFF1F5F9),
        const Color(0xFF1E293B),
      ),
      ProductStatus.inTransit => (
        const Color(0xFFFEF9C3),
        const Color(0xFF854D0E),
      ),
      ProductStatus.available => (
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      ProductStatus.sold => (const Color(0xFFF3F4F6), const Color(0xFF1F2937)),
      ProductStatus.damaged => (
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
      ),
      ProductStatus.returned => (
        const Color(0xFFF1F5F9),
        const Color(0xFF1E293B),
      ),
      ProductStatus.onOrder => (
        const Color(0xFFFFEDD5),
        const Color(0xFF9A3412),
      ),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF1F2937)),
    };
    return StatusBadge(label: s.label, background: bg, foreground: fg);
  }
}
