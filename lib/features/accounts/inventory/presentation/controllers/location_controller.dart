import 'package:get/get.dart';

import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/usecases/add_location_usecase.dart';
import '../../domain/usecases/get_locations_usecase.dart';

/// Shared, persisted list of stocking locations (used by the location
/// pickers on every inventory form).
class LocationController extends GetxController with NoticeMixin {
  LocationController(this._getLocations, this._addLocation);

  final GetLocationsUseCase _getLocations;
  final AddLocationUseCase _addLocation;

  final RxList<String> locations = <String>[].obs;

  /// Loads once; later calls are no-ops unless [force].
  Future<void> load({bool force = false}) async {
    if (locations.isNotEmpty && !force) return;
    final result = await _getLocations(const NoParams());
    // Keep whatever list we have on failure; the picker still lets users add.
    result.fold((_) {}, locations.assignAll);
  }

  Future<void> add(String name) async {
    final result = await _addLocation(name);
    result.fold(
      (_) => notify('Could not save the location', isError: true),
      locations.assignAll,
    );
  }
}
