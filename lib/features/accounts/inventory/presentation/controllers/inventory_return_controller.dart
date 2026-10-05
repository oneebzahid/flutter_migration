import 'package:get/get.dart';

import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../domain/entities/inventory_records.dart';
import '../../domain/usecases/get_damaged_usecase.dart';
import '../../domain/usecases/get_recent_invoices_usecase.dart';
import '../../domain/usecases/lookup_serial_usecase.dart';
import '../../domain/usecases/return_serial_usecase.dart';

enum ReturnSearch { idle, searching, found, notFound }

/// "Add Returned Inventory": look a serial up, then return it to stock or
/// move it to Damaged Inventory (reversing its invoice if it has one).
class InventoryReturnController extends GetxController with NoticeMixin {
  InventoryReturnController(
    this._lookupSerial,
    this._getRecentInvoices,
    this._getDamaged,
    this._returnSerial,
    this._session,
  );

  final LookupSerialUseCase _lookupSerial;
  final GetRecentInvoicesUseCase _getRecentInvoices;
  final GetDamagedUseCase _getDamaged;
  final ReturnSerialUseCase _returnSerial;
  final SessionProvider _session;

  final Rx<ReturnSearch> search = ReturnSearch.idle.obs;
  final Rxn<ReturnLookup> lookup = Rxn<ReturnLookup>();
  final Rx<Loadable<InvoiceRef>> invoices = const Loadable<InvoiceRef>().obs;
  final Rx<Loadable<DamagedRecord>> damaged =
      const Loadable<DamagedRecord>().obs;
  final RxBool submitting = false.obs;

  Future<void> searchSerial(String serial, {String? productId}) async {
    search.value = ReturnSearch.searching;
    lookup.value = null;
    final result = await _lookupSerial(
      LookupSerialParams(serial: serial, productId: productId),
    );
    result.fold(
      (_) {
        search.value = ReturnSearch.notFound;
        notify('Failed to search for serial number', isError: true);
      },
      (found) {
        lookup.value = found;
        search.value = found == null
            ? ReturnSearch.notFound
            : ReturnSearch.found;
      },
    );
  }

  Future<void> loadInvoices() async {
    invoices.value = invoices.value.loading();
    final result = await _getRecentInvoices(const GetRecentInvoicesParams());
    // React ignores this failure: the list is simply empty.
    result.fold(
      (_) => invoices.value = invoices.value.ready(const []),
      (items) => invoices.value = invoices.value.ready(items),
    );
  }

  Future<void> loadDamaged() async {
    damaged.value = damaged.value.loading();
    final result = await _getDamaged(const NoParams());
    result.fold(
      (f) => damaged.value = damaged.value.failed(f.message),
      (items) => damaged.value = damaged.value.ready(items),
    );
  }

  /// Notice tags: `return-stock` / `return-damaged`.
  Future<void> submit({
    required ReturnLookup found,
    required bool isDamaged,
    String reason = '',
  }) async {
    if (submitting.value) return;
    submitting.value = true;
    final serial = found.serial;
    final result = await _returnSerial(
      ReturnSerialParams(
        productId: found.product.id,
        serial: serial,
        damaged: isDamaged,
        reason: reason,
        invoice: found.invoice,
        by: DeletedBy.of(_session.currentUser),
      ),
    );
    submitting.value = false;
    await result.fold((f) async => notify(f.message, isError: true), (_) async {
      notify(
        isDamaged
            ? 'Serial $serial moved to Damaged Inventory'
            : 'Serial $serial returned to stock',
        tag: isDamaged ? 'return-damaged' : 'return-stock',
      );
      // Refresh what the screen shows.
      await loadInvoices();
      if (isDamaged) await loadDamaged();
    });
  }

  void reset() {
    search.value = ReturnSearch.idle;
    lookup.value = null;
    submitting.value = false;
  }
}
