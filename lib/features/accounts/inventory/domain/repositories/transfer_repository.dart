import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/product_transfer.dart';

/// Product transfers. Every method is ONE atomic operation (owner decision:
/// no read-then-write sequences in the presentation layer).
abstract interface class TransferRepository {
  /// Newest first.
  Future<Either<Failure, List<ProductTransfer>>> fetchTransfers();

  /// Serials (normalised) held by Pending / In Transit transfers; they cannot
  /// be offered for a new transfer.
  Future<Either<Failure, Set<String>>> fetchReservedSerials();

  /// Creates one Pending transfer per line, freight split by value. A repeated
  /// [TransferRequest.requestId] returns the first call's transfers without
  /// creating duplicates.
  Future<Either<Failure, List<ProductTransfer>>> createTransfers(
    TransferRequest request,
  );

  /// Pending -> In Transit; the serials become In Transit.
  Future<Either<Failure, Unit>> dispatchTransfer(String id);

  /// In Transit -> Received. Every serial must still be In Transit. Serials
  /// move to the destination and become Available; their original stock-in
  /// dates are kept.
  Future<Either<Failure, Unit>> receiveTransfer(
    String id, {
    required String receivedBy,
  });

  /// Pending / In Transit -> Cancelled; held serials are released.
  Future<Either<Failure, Unit>> cancelTransfer(String id);

  /// Removes the record. Open transfers release their serials; a Received
  /// transfer reverts the serials' location to the source.
  Future<Either<Failure, Unit>> deleteTransfer(String id);
}
