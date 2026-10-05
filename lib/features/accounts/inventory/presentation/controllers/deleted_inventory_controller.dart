import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/usecases/get_deleted_usecase.dart';

/// Read-only archive of deleted products / serials.
class DeletedInventoryController extends GetxController {
  DeletedInventoryController(this._getDeleted);

  final GetDeletedUseCase _getDeleted;

  final Rx<Loadable<DeletedProduct>> deleted =
      const Loadable<DeletedProduct>().obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    deleted.value = deleted.value.loading();
    final result = await _getDeleted(const NoParams());
    result.fold(
      (f) => deleted.value = deleted.value.failed(f.message),
      (items) => deleted.value = deleted.value.ready(items),
    );
  }
}
