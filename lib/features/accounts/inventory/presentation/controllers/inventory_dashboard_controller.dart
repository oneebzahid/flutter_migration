import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/entities/inventory_report_row.dart';
import '../../domain/usecases/delete_serial_usecase.dart';
import '../../domain/usecases/get_report_rows_usecase.dart';
import '../../../../../core/usecase/usecase.dart';

/// State + actions for the Inventory dashboard and the Inventory Report
/// (both show the per-serial report rows).
class InventoryDashboardController extends GetxController with NoticeMixin {
  InventoryDashboardController(
    this._getReportRows,
    this._deleteSerial,
    this._session,
  );

  final GetReportRowsUseCase _getReportRows;
  final DeleteSerialUseCase _deleteSerial;
  final SessionProvider _session;

  final Rx<Loadable<InventoryReportRow>> report =
      const Loadable<InventoryReportRow>().obs;

  /// A delete call is in flight (buttons stay disabled).
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  Future<void> loadReport() async {
    report.value = report.value.loading();
    final result = await _getReportRows(const NoParams());
    result.fold(
      (f) => report.value = report.value.failed(f.message),
      (rows) => report.value = report.value.ready(rows),
    );
  }

  /// Deletes serials one after another (like React, to avoid races on the
  /// same product document), then reloads the report.
  Future<void> deleteSerials(List<SerialRef> refs) async {
    if (refs.isEmpty || busy.value) return;
    busy.value = true;
    final by = DeletedBy.of(_session.currentUser);
    var ok = 0;
    var failed = 0;
    for (final r in refs) {
      final res = await _deleteSerial(
        DeleteSerialParams(
          productId: r.productId,
          serialNumber: r.serial,
          by: by,
        ),
      );
      res.fold((_) => failed++, (_) => ok++);
    }
    final single = refs.length == 1;
    String s(int n) => n == 1 ? '' : 's';
    if (failed == 0) {
      final r = refs.first;
      notify(
        single
            ? 'Serial ${r.serial.isEmpty ? '(no serial)' : r.serial} of '
                  '${r.brand} ${r.model} moved to Deleted Inventory'
            : '$ok serial${s(ok)} moved to Deleted Inventory',
        tag: 'delete-serials',
      );
    } else {
      notify(
        single
            ? 'Failed to delete item. Please try again.'
            : 'Deleted $ok, $failed failed — check console.',
        isError: true,
        tag: 'delete-serials',
      );
    }
    busy.value = false;
    await loadReport();
  }
}
