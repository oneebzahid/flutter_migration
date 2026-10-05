import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/usecases/get_damaged_usecase.dart';

/// Read-only list of serials moved to Damaged Inventory.
class DamagedInventoryController extends GetxController {
  DamagedInventoryController(this._getDamaged);

  final GetDamagedUseCase _getDamaged;

  final Rx<Loadable<DamagedRecord>> damaged =
      const Loadable<DamagedRecord>().obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    damaged.value = damaged.value.loading();
    final result = await _getDamaged(const NoParams());
    result.fold(
      (f) => damaged.value = damaged.value.failed(f.message),
      (items) => damaged.value = damaged.value.ready(items),
    );
  }
}
