import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/add_stock_usecase.dart';
import '../../domain/usecases/find_existing_serials_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';

/// "Add stock to an existing product": the product list plus the save call.
class InventoryAddExistingController extends GetxController with NoticeMixin {
  InventoryAddExistingController(
    this._getProducts,
    this._findExistingSerials,
    this._addStock,
  );

  final GetProductsUseCase _getProducts;
  final FindExistingSerialsUseCase _findExistingSerials;
  final AddStockUseCase _addStock;

  final Rx<Loadable<Product>> products = const Loadable<Product>().obs;
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  Future<void> loadProducts() async {
    products.value = products.value.loading();
    final result = await _getProducts(InventoryType.inStock);
    result.fold(
      (f) => products.value = products.value.failed(f.message),
      (items) => products.value = products.value.ready(items),
    );
  }

  /// Duplicate checks against the product's own serials are done by the
  /// screen; the "other products" check runs here. Notice tag: `add-stock`.
  Future<void> addStock({
    required String productId,
    required String modelName,
    required int quantity,
    required List<String> serials,
    required Map<String, String> serialCities,
    required double sellPrice,
    required double costPrice,
  }) async {
    if (busy.value) return;
    busy.value = true;
    String s(int n) => n == 1 ? '' : 's';

    final clash = await _findExistingSerials(
      FindExistingSerialsParams(serials: serials, exceptProductId: productId),
    );
    final clashing = clash.getOrElse(() => const []);
    if (clash.isLeft()) {
      busy.value = false;
      notify(clash.fold((f) => f.message, (_) => ''), isError: true);
      return;
    }
    if (clashing.isNotEmpty) {
      busy.value = false;
      notify(
        'Serial number${s(clashing.length)} already exists in another '
        'inventory item: ${clashing.join(', ')}',
        isError: true,
        tag: 'add-stock',
      );
      return;
    }

    final result = await _addStock(
      AddStockParams(
        productId: productId,
        serials: serials,
        serialCities: serialCities,
        sellPrice: sellPrice,
        costPrice: costPrice,
      ),
    );
    busy.value = false;
    result.fold(
      (f) => notify(f.message, isError: true),
      (_) => notify(
        'Added $quantity unit${s(quantity)} to $modelName',
        tag: 'add-stock',
      ),
    );
  }
}
