import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/usecases/add_brand_usecase.dart';
import '../../domain/usecases/add_model_usecase.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/generate_transaction_id_usecase.dart';
import '../../domain/usecases/get_brands_usecase.dart';
import '../../domain/usecases/get_models_usecase.dart';
import '../../domain/usecases/get_shipments_usecase.dart';
import '../../domain/usecases/save_model_profile_usecase.dart';

/// "Create inventory" entry form: brand / model / shipment lookups and the
/// save (which creates products one after another).
class CreateInventoryController extends GetxController with NoticeMixin {
  CreateInventoryController(
    this._getBrands,
    this._getModels,
    this._addBrand,
    this._addModel,
    this._getShipments,
    this._generateTransactionId,
    this._saveModelProfile,
    this._createProduct,
  );

  final GetBrandsUseCase _getBrands;
  final GetModelsUseCase _getModels;
  final AddBrandUseCase _addBrand;
  final AddModelUseCase _addModel;
  final GetShipmentsUseCase _getShipments;
  final GenerateTransactionIdUseCase _generateTransactionId;
  final SaveModelProfileUseCase _saveModelProfile;
  final CreateProductUseCase _createProduct;

  final Rx<Loadable<String>> brands = const Loadable<String>().obs;

  /// brand -> models (loaded on demand).
  final RxMap<String, Loadable<ModelOption>> models =
      <String, Loadable<ModelOption>>{}.obs;
  final Rx<Loadable<Shipment>> shipments = const Loadable<Shipment>().obs;

  /// Id shown in the entry header ("TXN: ...").
  final RxnString txnId = RxnString();
  final RxBool saving = false.obs;

  Loadable<ModelOption> modelsFor(String brand) =>
      models[brand] ?? const Loadable<ModelOption>();

  @override
  void onInit() {
    super.onInit();
    loadBrands();
    loadShipments();
    loadTxnId();
  }

  Future<void> loadBrands() async {
    brands.value = brands.value.loading();
    final r = await _getBrands(const NoParams());
    r.fold((_) {
      brands.value = brands.value.ready(const []);
      notify('Failed to load brands', isError: true, tag: 'brands');
    }, (items) => brands.value = brands.value.ready(items));
  }

  Future<void> loadModels(String brand) async {
    models[brand] = modelsFor(brand).loading();
    final r = await _getModels(brand);
    models[brand] = Loadable<ModelOption>().ready(r.getOrElse(() => const []));
  }

  Future<void> addBrand(String name) async {
    final r = await _addBrand(name);
    await r.fold(
      (_) async =>
          notify('Failed to save brand', isError: true, tag: 'brand-added'),
      (_) async {
        await loadBrands();
        notify('Brand "$name" saved', tag: 'brand-added');
      },
    );
  }

  Future<void> addModel(String brand, String model) async {
    final r = await _addModel(AddModelParams(brand: brand, model: model));
    await r.fold(
      (_) async =>
          notify('Failed to save model', isError: true, tag: 'model-added'),
      (_) async {
        await loadModels(brand);
        notify('Model "$model" saved', tag: 'model-added');
      },
    );
  }

  Future<void> loadShipments() async {
    shipments.value = shipments.value.loading();
    final r = await _getShipments(const NoParams());
    r.fold((_) {
      shipments.value = shipments.value.failed('Could not load shipments');
      notify('Could not load shipments', isError: true, tag: 'shipments');
    }, (items) => shipments.value = shipments.value.ready(items));
  }

  Future<void> loadTxnId() async {
    final r = await _generateTransactionId(const NoParams());
    // React falls back to a timestamp id.
    txnId.value = r.getOrElse(
      () => 'TXN-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Creates products one after another. With [continueOnError] a failed item
  /// is skipped (multi-model entry); otherwise the first failure stops the run
  /// and earlier items stay saved, as in React. Notice tags: `create-ok`,
  /// `create-fail`, `create-partial`.
  Future<void> createProducts(
    List<NewProductDraft> drafts, {
    bool continueOnError = false,
  }) async {
    if (saving.value) return;
    saving.value = true;
    String s(int n) => n == 1 ? '' : 's';
    var saved = 0;
    final failed = <String>[];
    String? lastError;

    for (final d in drafts) {
      // New brands / models are created on the way.
      await _addBrand(d.brandName);
      await _addModel(AddModelParams(brand: d.brandName, model: d.modelName));
      final r = await _createProduct(d);
      var ok = false;
      r.fold(
        (f) {
          lastError = f.message;
          failed.add('${d.brandName} ${d.modelName}'.trim());
        },
        (_) {
          saved++;
          ok = true;
        },
      );
      if (ok) {
        // Remember the values for next time; failures are ignored.
        await _saveModelProfile(
          SaveModelProfileParams(
            brand: d.brandName,
            profile: ModelOption(
              id: '',
              name: d.modelName,
              costPrice: d.costPrice,
              sellPrice: d.sellPrice,
              category: d.category,
              description: d.description,
              location: d.location,
            ),
          ),
        );
      } else if (!continueOnError) {
        break;
      }
    }

    saving.value = false;
    if (failed.isEmpty) {
      notify('$saved product${s(saved)} added to inventory', tag: 'create-ok');
    } else if (saved == 0) {
      notify(
        continueOnError
            ? 'Failed to save any items. Check console for details.'
            : (lastError ?? 'Failed to save inventory. Please try again.'),
        isError: true,
        tag: 'create-fail',
      );
    } else if (continueOnError) {
      notify(
        'Saved $saved, but ${failed.length} failed: ${failed.join(', ')}',
        tag: 'create-partial',
      );
    } else {
      // Stopped part-way: earlier rows are saved (no rollback).
      notify(
        '${lastError ?? 'Failed to save inventory.'} '
        '$saved product${s(saved)} saved before the error.',
        isError: true,
        tag: 'create-fail',
      );
    }
  }
}
