import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/rules/payable_rules.dart';
import '../../domain/usecases/get_banks_usecase.dart';
import '../../domain/usecases/get_payables_usecase.dart';
import '../../domain/usecases/get_supplier_payments_usecase.dart';
import '../../domain/usecases/record_supplier_payment_usecase.dart';

/// Inventory Payables: supplier-credit stock and what is still owed, plus
/// recording payments. Notice tag: `payment`.
class InventoryPayablesController extends GetxController with NoticeMixin {
  InventoryPayablesController(
    this._getPayables,
    this._getBanks,
    this._recordPayment,
    this._getPayments,
    this._currency,
  );

  final GetPayablesUseCase _getPayables;
  final GetBanksUseCase _getBanks;
  final RecordSupplierPaymentUseCase _recordPayment;
  final GetSupplierPaymentsUseCase _getPayments;
  final CurrencyProvider _currency;

  final Rx<Loadable<Product>> payables = const Loadable<Product>().obs;
  final Rx<Loadable<BankAccount>> banks = const Loadable<BankAccount>().obs;

  /// A payment is being saved (the dialog button stays disabled).
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    payables.value = payables.value.loading();
    final result = await _getPayables(const NoParams());
    result.fold(
      (f) => payables.value = payables.value.failed(
        f.message.isEmpty ? 'Failed to load inventory payables' : f.message,
      ),
      (items) => payables.value = payables.value.ready(items),
    );
  }

  Future<void> loadBanks() async {
    banks.value = banks.value.loading();
    final result = await _getBanks(const NoParams());
    // React: an error leaves the list empty.
    banks.value = banks.value.ready(result.getOrElse(() => const []));
  }

  Future<List<SupplierPayment>> history(String productId) async =>
      (await _getPayments(productId)).getOrElse(() => const []);

  /// Records a payment; returns true when it was saved (so the dialog can
  /// close). [requestId] must stay the same for one dialog.
  Future<bool> pay({
    required Product product,
    required double amount,
    required PaymentChannel channel,
    required String? bankId,
    required String requestId,
  }) async {
    if (busy.value) return false;
    if (amount <= 0) {
      notify('Enter a valid payment amount', isError: true);
      return false;
    }
    busy.value = true;
    final result = await _recordPayment(
      SupplierPaymentRequest(
        productId: product.id,
        amount: amount,
        channel: channel,
        bankId: bankId,
        requestId: requestId,
      ),
    );
    busy.value = false;
    final ok = result.isRight();
    result.fold((f) => notify(f.message, isError: true), (_) {
      notify(
        'Payment of ${formatCurrency(amount, _currency.currencyCode.value)} '
        'recorded for ${product.brandName} ${product.modelName}',
        tag: 'payment',
      );
    });
    if (ok) await load();
    return ok;
  }

  /// Totals ignore the search filter, as in React.
  ({double dueNow, double stillInStock}) get totals =>
      PayableRules.totals(payables.value.items);
}
