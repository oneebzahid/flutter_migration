import 'package:dartz/dartz.dart';
import 'package:get/get.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_transfer.dart';
import '../../domain/usecases/cancel_transfer_usecase.dart';
import '../../domain/usecases/create_transfers_usecase.dart';
import '../../domain/usecases/delete_transfer_usecase.dart';
import '../../domain/usecases/dispatch_transfer_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../../domain/usecases/get_reserved_serials_usecase.dart';
import '../../domain/usecases/get_transfers_usecase.dart';
import '../../domain/usecases/receive_transfer_usecase.dart';

/// Product Transfer list + the new-transfer form (they share the transfer
/// data). Every action is one use case and re-loads the list afterwards.
class ProductTransferController extends GetxController with NoticeMixin {
  ProductTransferController(
    this._getTransfers,
    this._getReserved,
    this._create,
    this._dispatch,
    this._receive,
    this._cancel,
    this._delete,
    this._getProducts,
  );

  final GetTransfersUseCase _getTransfers;
  final GetReservedSerialsUseCase _getReserved;
  final CreateTransfersUseCase _create;
  final DispatchTransferUseCase _dispatch;
  final ReceiveTransferUseCase _receive;
  final CancelTransferUseCase _cancel;
  final DeleteTransferUseCase _delete;
  final GetProductsUseCase _getProducts;

  final Rx<Loadable<ProductTransfer>> transfers =
      const Loadable<ProductTransfer>().obs;

  /// Normalised serials held by open transfers (not offered for a new one).
  final RxSet<String> reserved = <String>{}.obs;

  /// In-stock products, for picking serials on the create form.
  final Rx<Loadable<Product>> products = const Loadable<Product>().obs;

  /// A create/dispatch/receive/cancel/delete call is in flight (buttons stay
  /// disabled so nothing can be submitted twice).
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    transfers.value = transfers.value.loading();
    final result = await _getTransfers(const NoParams());
    result.fold(
      (f) => transfers.value = transfers.value.failed(f.message),
      (items) => transfers.value = transfers.value.ready(items),
    );
    final res = await _getReserved(const NoParams());
    res.fold((_) {}, reserved.assignAll);
  }

  /// Loads stock for the create form.
  Future<void> loadProducts() async {
    products.value = products.value.loading();
    final result = await _getProducts(InventoryType.inStock);
    result.fold(
      (f) => products.value = products.value.failed(f.message),
      (items) => products.value = products.value.ready(items),
    );
  }

  /// Runs one command: busy flag, notice, then reload. Notice tag = [tag].
  Future<void> _run<T>(
    Future<Either<Failure, T>> Function() call,
    String success,
    String tag,
  ) async {
    if (busy.value) return;
    busy.value = true;
    final result = await call();
    busy.value = false;
    final failure = result.fold<String?>((f) => f.message, (_) => null);
    if (failure != null) {
      notify(failure, isError: true);
      return;
    }
    notify(success, tag: tag);
    await load();
  }

  Future<void> createTransfers(TransferRequest request) => _run(
    () => _create(request),
    'Transfer created successfully — pending dispatch',
    'create',
  );

  Future<void> dispatch(String id) => _run(
    () => _dispatch(id),
    'Transfer dispatched — now In Transit',
    'dispatch',
  );

  Future<void> receive(String id, String receivedBy) => _run(
    () => _receive(ReceiveTransferParams(id: id, receivedBy: receivedBy)),
    'Transfer received — stock moved to the destination',
    'receive',
  );

  Future<void> cancel(String id) =>
      _run(() => _cancel(id), 'Transfer cancelled', 'cancel');

  Future<void> deleteTransfer(String id) =>
      _run(() => _delete(id), 'Transfer record deleted', 'delete');
}
