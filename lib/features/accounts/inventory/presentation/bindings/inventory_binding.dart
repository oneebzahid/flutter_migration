import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../../../auth/domain/repositories/session_provider.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../data/repositories/payables_repository_impl.dart';
import '../../data/repositories/transfer_repository_impl.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/repositories/payables_repository.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../../domain/usecases/add_brand_usecase.dart';
import '../../domain/usecases/add_location_usecase.dart';
import '../../domain/usecases/add_model_usecase.dart';
import '../../domain/usecases/add_stock_usecase.dart';
import '../../domain/usecases/cancel_transfer_usecase.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/create_transfers_usecase.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../domain/usecases/delete_serial_usecase.dart';
import '../../domain/usecases/delete_transfer_usecase.dart';
import '../../domain/usecases/dispatch_transfer_usecase.dart';
import '../../domain/usecases/find_existing_serials_usecase.dart';
import '../../domain/usecases/generate_transaction_id_usecase.dart';
import '../../domain/usecases/get_brands_usecase.dart';
import '../../domain/usecases/get_damaged_usecase.dart';
import '../../domain/usecases/get_deleted_usecase.dart';
import '../../domain/usecases/get_locations_usecase.dart';
import '../../domain/usecases/get_models_usecase.dart';
import '../../domain/usecases/get_banks_usecase.dart';
import '../../domain/usecases/get_payables_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../../domain/usecases/get_supplier_payments_usecase.dart';
import '../../domain/usecases/record_supplier_payment_usecase.dart';
import '../../domain/usecases/get_recent_invoices_usecase.dart';
import '../../domain/usecases/get_report_rows_usecase.dart';
import '../../domain/usecases/get_reserved_serials_usecase.dart';
import '../../domain/usecases/get_shipments_usecase.dart';
import '../../domain/usecases/get_transfers_usecase.dart';
import '../../domain/usecases/lookup_serial_usecase.dart';
import '../../domain/usecases/receive_product_usecase.dart';
import '../../domain/usecases/receive_transfer_usecase.dart';
import '../../domain/usecases/return_serial_usecase.dart';
import '../../domain/usecases/save_model_profile_usecase.dart';
import '../controllers/create_inventory_controller.dart';
import '../controllers/damaged_inventory_controller.dart';
import '../controllers/deleted_inventory_controller.dart';
import '../controllers/inventory_add_existing_controller.dart';
import '../controllers/inventory_dashboard_controller.dart';
import '../controllers/inventory_list_controller.dart';
import '../controllers/inventory_payables_controller.dart';
import '../controllers/inventory_return_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/product_transfer_controller.dart';

/// Wires the whole Inventory feature (all its routes share this binding),
/// narrowest layer first. Everything is `lazyPut`, so nothing is built until
/// a route that needs it is visited.
///
/// The [InventoryDataSource] itself is registered app-wide in
/// `InitialBindings` while the data is an in-memory mock (the mock must
/// outlive a single route); a real Supabase datasource is stateless and moves
/// here.
class InventoryBinding extends Bindings {
  @override
  void dependencies() {
    // ── repositories ──
    Get.lazyPut<InventoryRepository>(
      () => InventoryRepositoryImpl(Get.find<InventoryDataSource>()),
    );
    Get.lazyPut<CatalogRepository>(
      () => CatalogRepositoryImpl(Get.find<InventoryDataSource>()),
    );
    Get.lazyPut<TransferRepository>(
      () => TransferRepositoryImpl(Get.find<InventoryDataSource>()),
    );

    Get.lazyPut<PayablesRepository>(
      () => PayablesRepositoryImpl(Get.find<InventoryDataSource>()),
    );

    // ── use cases: payables ──
    Get.lazyPut(() => GetPayablesUseCase(Get.find<PayablesRepository>()));
    Get.lazyPut(() => GetBanksUseCase(Get.find<PayablesRepository>()));
    Get.lazyPut(
      () => RecordSupplierPaymentUseCase(Get.find<PayablesRepository>()),
    );
    Get.lazyPut(
      () => GetSupplierPaymentsUseCase(Get.find<PayablesRepository>()),
    );

    // ── use cases: inventory ──
    Get.lazyPut(() => GetProductsUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => GetReportRowsUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => GetDamagedUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => GetDeletedUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => DeleteProductUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => DeleteSerialUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => ReceiveProductUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => AddStockUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(
      () => FindExistingSerialsUseCase(Get.find<InventoryRepository>()),
    );
    Get.lazyPut(() => LookupSerialUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(
      () => GetRecentInvoicesUseCase(Get.find<InventoryRepository>()),
    );
    Get.lazyPut(() => ReturnSerialUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => GetLocationsUseCase(Get.find<InventoryRepository>()));
    Get.lazyPut(() => AddLocationUseCase(Get.find<InventoryRepository>()));

    // ── use cases: catalog ──
    Get.lazyPut(() => GetBrandsUseCase(Get.find<CatalogRepository>()));
    Get.lazyPut(() => GetModelsUseCase(Get.find<CatalogRepository>()));
    Get.lazyPut(() => AddBrandUseCase(Get.find<CatalogRepository>()));
    Get.lazyPut(() => AddModelUseCase(Get.find<CatalogRepository>()));
    Get.lazyPut(() => GetShipmentsUseCase(Get.find<CatalogRepository>()));
    Get.lazyPut(
      () => GenerateTransactionIdUseCase(Get.find<CatalogRepository>()),
    );
    Get.lazyPut(() => SaveModelProfileUseCase(Get.find<CatalogRepository>()));
    Get.lazyPut(() => CreateProductUseCase(Get.find<CatalogRepository>()));

    // ── use cases: transfers ──
    Get.lazyPut(() => GetTransfersUseCase(Get.find<TransferRepository>()));
    Get.lazyPut(
      () => GetReservedSerialsUseCase(Get.find<TransferRepository>()),
    );
    Get.lazyPut(() => CreateTransfersUseCase(Get.find<TransferRepository>()));
    Get.lazyPut(() => DispatchTransferUseCase(Get.find<TransferRepository>()));
    Get.lazyPut(() => ReceiveTransferUseCase(Get.find<TransferRepository>()));
    Get.lazyPut(() => CancelTransferUseCase(Get.find<TransferRepository>()));
    Get.lazyPut(() => DeleteTransferUseCase(Get.find<TransferRepository>()));

    // ── controllers ──
    Get.lazyPut(
      () => InventoryDashboardController(
        Get.find(),
        Get.find(),
        Get.find<SessionProvider>(),
      ),
    );
    Get.lazyPut(
      () => InventoryListController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find<SessionProvider>(),
      ),
    );
    Get.lazyPut(() => DamagedInventoryController(Get.find()));
    Get.lazyPut(() => DeletedInventoryController(Get.find()));
    Get.lazyPut(
      () => InventoryAddExistingController(Get.find(), Get.find(), Get.find()),
    );
    Get.lazyPut(
      () => InventoryReturnController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find<SessionProvider>(),
      ),
    );
    Get.lazyPut(
      () => CreateInventoryController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
      ),
    );
    Get.lazyPut(() => LocationController(Get.find(), Get.find()));
    Get.lazyPut(
      () => InventoryPayablesController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find<CurrencyProvider>(),
      ),
    );
    Get.lazyPut(
      () => ProductTransferController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
      ),
    );
  }
}
