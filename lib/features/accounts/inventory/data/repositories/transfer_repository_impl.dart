import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/product_transfer.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/inventory_datasource.dart';

/// Bridges [InventoryDataSource] (throws exceptions) to [TransferRepository]
/// (returns `Either<Failure, T>`). The only try/catch lives in `guardCall`.
class TransferRepositoryImpl implements TransferRepository {
  TransferRepositoryImpl(this._source);

  final InventoryDataSource _source;

  @override
  Future<Either<Failure, List<ProductTransfer>>> fetchTransfers() => guardCall(
    () => _source.fetchTransfers(),
    fallback: 'Failed to load transfers',
  );

  @override
  Future<Either<Failure, Set<String>>> fetchReservedSerials() => guardCall(
    () => _source.fetchReservedSerials(),
    fallback: 'Something went wrong. Please try again.',
  );

  @override
  Future<Either<Failure, List<ProductTransfer>>> createTransfers(
    TransferRequest request,
  ) => guardCall(
    () => _source.createTransfers(request),
    fallback: 'Failed to create transfer',
  );

  @override
  Future<Either<Failure, Unit>> dispatchTransfer(String id) =>
      guardCall(() async {
        await _source.dispatchTransfer(id);
        return unit;
      }, fallback: 'Failed to dispatch transfer');

  @override
  Future<Either<Failure, Unit>> receiveTransfer(
    String id, {
    required String receivedBy,
  }) => guardCall(() async {
    await _source.receiveTransfer(id, receivedBy: receivedBy);
    return unit;
  }, fallback: 'Failed to receive transfer');

  @override
  Future<Either<Failure, Unit>> cancelTransfer(String id) =>
      guardCall(() async {
        await _source.cancelTransfer(id);
        return unit;
      }, fallback: 'Failed to cancel transfer');

  @override
  Future<Either<Failure, Unit>> deleteTransfer(String id) =>
      guardCall(() async {
        await _source.deleteTransfer(id);
        return unit;
      }, fallback: 'Failed to delete transfer');
}
