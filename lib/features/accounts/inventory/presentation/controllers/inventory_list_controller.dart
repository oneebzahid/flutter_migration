import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../../domain/usecases/receive_product_usecase.dart';

/// The product list (in-stock and on-order) with delete / receive actions.
class InventoryListController extends GetxController with NoticeMixin {
  InventoryListController(
    this._getProducts,
    this._deleteProduct,
    this._receiveProduct,
    this._session,
  );

  final GetProductsUseCase _getProducts;
  final DeleteProductUseCase _deleteProduct;
  final ReceiveProductUseCase _receiveProduct;
  final SessionProvider _session;

  final Rx<Loadable<Product>> inStock = const Loadable<Product>().obs;
  final Rx<Loadable<Product>> onOrder = const Loadable<Product>().obs;
  final RxBool busy = false.obs;

  Rx<Loadable<Product>> _rx(InventoryType t) =>
      t == InventoryType.onOrder ? onOrder : inStock;

  Loadable<Product> listFor(InventoryType t) => _rx(t).value;

  Future<void> load(InventoryType type) async {
    final rx = _rx(type);
    rx.value = rx.value.loading();
    final result = await _getProducts(type);
    result.fold(
      (f) => rx.value = rx.value.failed(f.message),
      (items) => rx.value = rx.value.ready(items),
    );
  }

  /// Like React, the row disappears locally right away (no refetch needed).
  void _removeLocally(String id) {
    inStock.value = inStock.value.copyWith(
      items: inStock.value.items.where((p) => p.id != id).toList(),
    );
    onOrder.value = onOrder.value.copyWith(
      items: onOrder.value.items.where((p) => p.id != id).toList(),
    );
  }

  Future<void> deleteProduct(String id) async {
    if (busy.value) return;
    busy.value = true;
    final result = await _deleteProduct(
      DeleteProductParams(id: id, by: DeletedBy.of(_session.currentUser)),
    );
    busy.value = false;
    result.fold((f) => notify(f.message, isError: true), (_) {
      _removeLocally(id);
      notify('Item moved to Deleted Inventory', tag: 'delete');
    });
  }

  Future<void> receiveProduct(String id) async {
    if (busy.value) return;
    busy.value = true;
    final result = await _receiveProduct(id);
    busy.value = false;
    result.fold((f) => notify(f.message, isError: true), (_) {
      _removeLocally(id);
      notify('Product moved to stock successfully', tag: 'receive');
    });
  }
}
