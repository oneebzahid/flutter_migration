import 'package:equatable/equatable.dart';

/// Pending -> In Transit -> Received, with Cancel from Pending / In Transit
/// (owner decision 4).
enum TransferStatus {
  pending('Pending'),
  inTransit('In Transit'),
  received('Received'),
  cancelled('Cancelled');

  const TransferStatus(this.label);
  final String label;

  /// Still holds its serials.
  bool get isOpen => this == pending || this == inTransit;
}

class ProductTransfer extends Equatable {
  const ProductTransfer({
    required this.id,
    required this.groupId,
    required this.date,
    required this.productId,
    required this.brandName,
    required this.modelName,
    required this.from,
    required this.to,
    required this.serials,
    required this.transferredBy,
    this.shipmentCost = 0,
    this.status = TransferStatus.pending,
    this.receivedBy,
    this.receivedAt,
  });

  final String id;

  /// Transfers created together share a group (one freight total).
  final String groupId;
  final DateTime date;
  final String productId;
  final String brandName;
  final String modelName;
  final String from;
  final String to;
  final List<String> serials;
  final String transferredBy;

  /// This transfer's share of the freight (shares add up to the total).
  final double shipmentCost;
  final TransferStatus status;
  final String? receivedBy;
  final DateTime? receivedAt;

  int get quantity => serials.length;
  String get productLabel => '$brandName $modelName';

  bool get canDispatch => status == TransferStatus.pending;
  bool get canReceive => status == TransferStatus.inTransit;
  bool get canCancel => status.isOpen;

  ProductTransfer copyWith({
    TransferStatus? status,
    String? receivedBy,
    DateTime? receivedAt,
  }) => ProductTransfer(
    id: id,
    groupId: groupId,
    date: date,
    productId: productId,
    brandName: brandName,
    modelName: modelName,
    from: from,
    to: to,
    serials: serials,
    transferredBy: transferredBy,
    shipmentCost: shipmentCost,
    status: status ?? this.status,
    receivedBy: receivedBy ?? this.receivedBy,
    receivedAt: receivedAt ?? this.receivedAt,
  );

  @override
  List<Object?> get props => [
    id,
    groupId,
    date,
    productId,
    from,
    to,
    serials,
    transferredBy,
    shipmentCost,
    status,
    receivedBy,
    receivedAt,
  ];
}

/// One product line of a new transfer.
class TransferLine extends Equatable {
  const TransferLine({
    required this.productId,
    required this.serials,
    this.unitValue = 0,
  });
  final String productId;
  final List<String> serials;

  /// Cost per unit, used to weight the freight split.
  final double unitValue;

  @override
  List<Object?> get props => [productId, serials, unitValue];
}

class TransferRequest extends Equatable {
  const TransferRequest({
    required this.date,
    required this.transferredBy,
    required this.from,
    required this.to,
    required this.lines,
    this.shipmentCost = 0,
    required this.requestId,
  });

  final DateTime date;
  final String transferredBy;
  final String from;
  final String to;
  final List<TransferLine> lines;
  final double shipmentCost;

  /// One id per submit; a repeated id is ignored (double-submit guard).
  final String requestId;

  @override
  List<Object?> get props => [
    date,
    transferredBy,
    from,
    to,
    lines,
    shipmentCost,
    requestId,
  ];
}
