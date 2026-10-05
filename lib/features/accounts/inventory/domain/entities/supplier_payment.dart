import 'package:equatable/equatable.dart';

/// How a supplier was paid (React offers Cash and Bank here).
enum PaymentChannel {
  cash('Cash'),
  bank('Bank');

  const PaymentChannel(this.label);
  final String label;
}

/// A bank account a supplier payment can be made from.
class BankAccount extends Equatable {
  const BankAccount({required this.id, required this.name, this.balance});
  final String id;
  final String name;
  final double? balance;

  @override
  List<Object?> get props => [id, name, balance];
}

/// One payment to a supplier for a credit product. Unlike React (which only
/// overwrote the paid total), each payment is kept as an immutable record.
class SupplierPayment extends Equatable {
  const SupplierPayment({
    required this.id,
    required this.productId,
    required this.label,
    required this.amount,
    required this.channel,
    required this.date,
    required this.reference,
    this.bankName,
  });

  final String id;
  final String productId;

  /// "Brand Model", as shown on the ledger row.
  final String label;
  final double amount;
  final PaymentChannel channel;
  final String? bankName;
  final DateTime date;

  /// `SUP-PAY-<productId>-<timestamp>`, as React.
  final String reference;

  @override
  List<Object?> get props => [
    id,
    productId,
    label,
    amount,
    channel,
    bankName,
    date,
    reference,
  ];
}

/// Input for recording a payment.
class SupplierPaymentRequest extends Equatable {
  const SupplierPaymentRequest({
    required this.productId,
    required this.amount,
    required this.channel,
    required this.requestId,
    this.bankId,
  });

  final String productId;
  final double amount;
  final PaymentChannel channel;
  final String? bankId;

  /// One id per dialog submit; a repeated id is ignored (double-submit guard).
  final String requestId;

  @override
  List<Object?> get props => [productId, amount, channel, bankId, requestId];
}
