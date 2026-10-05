import 'package:equatable/equatable.dart';

import '../../../../auth/domain/entities/auth_user.dart';
import 'product.dart';

/// Who performed an action (recorded on archived / deleted records).
class DeletedBy extends Equatable {
  const DeletedBy({required this.uid, required this.email, required this.name});

  /// React falls back to this when nobody is signed in.
  static const unknown = DeletedBy(
    uid: 'unknown',
    email: 'unknown@system',
    name: 'Unknown User',
  );

  /// The signed-in user, or [unknown] when nobody is.
  factory DeletedBy.of(AuthUser? user) => user == null
      ? unknown
      : DeletedBy(uid: user.uid, email: user.email, name: user.email);

  final String uid;
  final String email;
  final String name;

  @override
  List<Object?> get props => [uid, email, name];
}

/// One serial of a product, as picked for deletion on the dashboard.
class SerialRef extends Equatable {
  const SerialRef({
    required this.productId,
    required this.serial,
    required this.brand,
    required this.model,
  });
  final String productId;
  final String serial;
  final String brand;
  final String model;

  @override
  List<Object?> get props => [productId, serial, brand, model];
}

/// A serial moved to Damaged Inventory (React `DamagedProduct`).
class DamagedRecord extends Equatable {
  const DamagedRecord({
    required this.id,
    required this.productId,
    required this.brandName,
    required this.modelName,
    required this.serialNumber,
    required this.damagedAt,
    this.location = '',
    this.reason = '',
    this.damagedBy = '',
  });

  final String id;
  final String productId;
  final String brandName;
  final String modelName;
  final String serialNumber;
  final String location;
  final String reason;
  final DateTime damagedAt;
  final String damagedBy;

  @override
  List<Object?> get props => [
    id,
    productId,
    brandName,
    modelName,
    serialNumber,
    location,
    reason,
    damagedAt,
    damagedBy,
  ];
}

/// An archived (deleted) product or single serial (React `DeletedProduct`).
class DeletedProduct extends Equatable {
  const DeletedProduct({
    required this.archiveId,
    required this.originalId,
    required this.product,
    required this.deletedAt,
    required this.deletedBy,
    this.serialScope = false,
  });

  final String archiveId;
  final String originalId;

  /// Snapshot at the moment of deletion.
  final Product product;
  final DateTime deletedAt;
  final DeletedBy deletedBy;

  /// True when only one serial was deleted (stock 1, a single serial).
  final bool serialScope;

  /// Product location, else the most frequent per-serial city (React
  /// `getDisplayLocation`), else an em dash.
  String get displayLocation {
    final loc = product.location;
    if (loc != null && loc.isNotEmpty) return loc;
    final cities = product.serialCities.values.where((c) => c.isNotEmpty);
    if (cities.isEmpty) return '—';
    final freq = <String, int>{};
    for (final c in cities) {
      freq[c] = (freq[c] ?? 0) + 1;
    }
    return (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  @override
  List<Object?> get props => [
    archiveId,
    originalId,
    product,
    deletedAt,
    deletedBy,
    serialScope,
  ];
}

class InvoiceLine extends Equatable {
  const InvoiceLine({required this.productId, required this.serials});
  final String productId;
  final List<String> serials;

  @override
  List<Object?> get props => [productId, serials];
}

/// The slice of an invoice the return flow needs (the Invoices module is
/// migrated separately).
class InvoiceRef extends Equatable {
  const InvoiceRef({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.lines,
  });

  final String id;
  final String invoiceNumber;
  final String customerName;
  final DateTime date;
  final double totalAmount;
  final List<InvoiceLine> lines;

  /// Every serial on the invoice, with the product it belongs to.
  List<(String productId, String serial)> get serialRefs => [
    for (final l in lines)
      for (final s in l.serials)
        if (s.trim().isNotEmpty) (l.productId, s),
  ];

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    customerName,
    date,
    totalAmount,
    lines,
  ];
}

/// Result of looking a serial up for a return.
class ReturnLookup extends Equatable {
  const ReturnLookup({
    required this.product,
    required this.serial,
    this.invoice,
  });

  final Product product;
  final String serial;

  /// The invoice this serial was sold on, if any.
  final InvoiceRef? invoice;

  @override
  List<Object?> get props => [product, serial, invoice];
}
