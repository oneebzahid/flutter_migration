import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/core/routes/app_routes.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/inventory_records.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/inventory_report_row.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/add_stock_rules.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/inventory_logic.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/bindings/inventory_binding.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/damaged_inventory_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/deleted_inventory_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_add_existing_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_dashboard_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_list_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_return_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/location_controller.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:bullion_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1700, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  resetGet();
  await tester.pumpWidget(BullionApp(initialBinding: Harness.fresh().bindings));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).at(0),
    MockAuthDataSource.demoAdminEmail,
  );
  await tester.enterText(
    find.byType(TextFormField).at(1),
    MockAuthDataSource.demoAdminPassword,
  );
  await tester.tap(find.text('Sign in').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Inventory').first);
  await tester.pumpAndSettle();
}

Finder _hint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

void main() {
  group('AddStockRules', () {
    test('count must equal the units being added', () {
      expect(
        AddStockRules.validate(
          quantity: 2,
          serialInputs: ['A', ''],
          existingOnProduct: const [],
        ),
        'Please provide 2 serial numbers',
      );
      expect(
        AddStockRules.validate(
          quantity: 1,
          serialInputs: [''],
          existingOnProduct: const [],
        ),
        'Please provide 1 serial number',
      );
    });

    test('duplicates inside the batch are named', () {
      expect(
        AddStockRules.validate(
          quantity: 3,
          serialInputs: ['A', 'B', 'A'],
          existingOnProduct: const [],
        ),
        'Duplicate serial in the new batch: A',
      );
      expect(
        AddStockRules.validate(
          quantity: 4,
          serialInputs: ['A', 'B', 'A', 'B'],
          existingOnProduct: const [],
        ),
        'Duplicate serials in the new batch: A, B',
      );
    });

    test('clash with the product\'s own serials is reported', () {
      expect(
        AddStockRules.validate(
          quantity: 1,
          serialInputs: ['X1'],
          existingOnProduct: const ['X1', 'X2'],
        ),
        'Duplicate serial: X1',
      );
    });

    test('whitespace is trimmed so "SN1" and "SN1 " are one serial', () {
      expect(AddStockRules.filled([' SN1 ', '', 'SN2']), ['SN1', 'SN2']);
      expect(
        AddStockRules.validate(
          quantity: 2,
          serialInputs: ['SN1', 'SN1 '],
          existingOnProduct: const [],
        ),
        'Duplicate serial in the new batch: SN1',
      );
    });

    test(
      'valid input returns null; prices and quantity fall back like React',
      () {
        expect(
          AddStockRules.validate(
            quantity: 2,
            serialInputs: ['A', 'B'],
            existingOnProduct: const ['Z'],
          ),
          isNull,
        );
        expect(AddStockRules.parseQuantity(''), 1);
        expect(AddStockRules.parseQuantity('0'), 1);
        expect(AddStockRules.parseQuantity('5'), 5);
        expect(AddStockRules.parsePrice('abc'), 0);
        expect(AddStockRules.parsePrice('-4'), 0);
        expect(AddStockRules.parsePrice('1,250.5'), 1250.5);
      },
    );
  });

  group('deleted & damaged data', () {
    setUp(() {
      Harness.install();
      InventoryBinding().dependencies();
    });

    test('seed archive and damaged list load newest first', () async {
      final deleted = Get.find<DeletedInventoryController>();
      final damaged = Get.find<DamagedInventoryController>();
      await deleted.load();
      await damaged.load();
      final list = deleted.deleted.value.items;
      expect(list.length, 2);
      expect(list.first.deletedAt.isAfter(list.last.deletedAt), isTrue);
      expect(damaged.damaged.value.items.length, 2);
    });

    test('deleting a product archives it with the signed-in user', () async {
      await Get.find<AuthController>().login(
        MockAuthDataSource.demoAdminEmail,
        MockAuthDataSource.demoAdminPassword,
      );
      await Get.find<InventoryListController>().deleteProduct('p09');
      final deleted = Get.find<DeletedInventoryController>();
      await deleted.load();
      final entry = deleted.deleted.value.items.firstWhere(
        (d) => d.originalId == 'p09' && !d.serialScope,
      );
      expect(entry.deletedBy.email, MockAuthDataSource.demoAdminEmail);
    });

    test(
      'with nobody signed in the archive records the React fallback user',
      () async {
        await Get.find<InventoryListController>().deleteProduct('p09');
        final deleted = Get.find<DeletedInventoryController>();
        await deleted.load();
        final entry = deleted.deleted.value.items.firstWhere(
          (d) => d.originalId == 'p09' && d.archiveId != 'arch-seed-1',
        );
        expect(entry.deletedBy, DeletedBy.unknown);
      },
    );

    test('deleting one serial archives a one-unit snapshot', () async {
      final dash = Get.find<InventoryDashboardController>();
      await dash.loadReport();
      final r = dash.report.value.items.firstWhere((r) => r.productId == 'p02');
      await dash.deleteSerials([
        SerialRef(
          productId: 'p02',
          serial: r.serialNumber,
          brand: 'Garrett',
          model: 'Super Scanner V',
        ),
      ]);
      final deleted = Get.find<DeletedInventoryController>();
      await deleted.load();
      final entry = deleted.deleted.value.items.firstWhere(
        (d) => d.serialScope && d.originalId == 'p02',
      );
      expect(entry.product.stock, 1);
      expect(entry.product.serialNumbers, [r.serialNumber]);
    });

    test('display location falls back to the most common serial city', () {
      final d = DeletedProduct(
        archiveId: 'a',
        originalId: 'o',
        deletedAt: DateTime(2026, 1, 1),
        deletedBy: DeletedBy.unknown,
        product: const Product(
          id: 'o',
          brandName: 'B',
          modelName: 'M',
          category: 'C',
          sellPrice: 1,
          buyType: BuyType.import,
          warrantyYears: 1,
          serialNumbers: ['1', '2', '3'],
          status: ProductStatus.available,
          serialCities: {'1': 'Dubai', '2': 'Riyadh', '3': 'Dubai'},
        ),
      );
      expect(d.displayLocation, 'Dubai');
    });
  });

  group('add stock flow', () {
    late InventoryAddExistingController c;

    setUp(() async {
      Harness.install();
      InventoryBinding().dependencies();
      c = Get.find<InventoryAddExistingController>();
      await c.loadProducts();
    });

    test('adds units, serials, cities and averages cost and only raises the sell price', () async {
      final before = c.products.value.items.firstWhere((p) => p.id == 'p02');
      await c.addStock(
        productId: 'p02',
        modelName: 'Super Scanner V',
        quantity: 2,
        serials: const ['NEW-1', 'NEW-2'],
        serialCities: const {'NEW-1': 'Riyadh Store'},
        sellPrice: 31000,
        costPrice: 22000,
      );
      expect(c.notice.value?.message, 'Added 2 units to Super Scanner V');
      await c.loadProducts();
      final after = c.products.value.items.firstWhere((p) => p.id == 'p02');
      expect(after.stock, before.stock + 2);
      expect(after.serialNumbers, containsAll(['NEW-1', 'NEW-2']));
      expect(after.serialCities['NEW-1'], 'Riyadh Store');
      expect(
        after.sellPrice,
        before.sellPrice > 31000 ? before.sellPrice : 31000,
      );
      expect(
        after.costPrice,
        StockValuation.weightedAverageCost(
          availableQty: before.stock,
          availableCost: before.costPrice!,
          newQty: 2,
          newCost: 22000,
        ),
      );
    });

    test('a serial that belongs to another product is rejected', () async {
      await c.addStock(
        productId: 'p02',
        modelName: 'Super Scanner V',
        quantity: 1,
        serials: const ['P01-0001'],
        serialCities: const {},
        sellPrice: 1,
        costPrice: 1,
      );
      expect(c.notice.value?.isError, isTrue);
      expect(
        c.notice.value?.message,
        'Serial number already exists in another inventory item: P01-0001',
      );
    });

    test('the clash check ignores case and surrounding spaces', () async {
      await c.addStock(
        productId: 'p02',
        modelName: 'Super Scanner V',
        quantity: 1,
        serials: const [' p01-0001 '],
        serialCities: const {},
        sellPrice: 1,
        costPrice: 1,
      );
      expect(c.notice.value?.isError, isTrue);
    });

    test('locations can be added and stay sorted without duplicates', () async {
      final loc = Get.find<LocationController>();
      await loc.load();
      await loc.add('Karachi');
      await loc.add('karachi');
      final l = loc.locations.toList();
      expect(l.where((x) => x.toLowerCase() == 'karachi').length, 1);
      expect([...l]..sort(), l);
    });
  });

  group('return flow', () {
    late InventoryReturnController c;

    setUp(() async {
      Harness.install();
      InventoryBinding().dependencies();
      c = Get.find<InventoryReturnController>();
      await c.loadInvoices();
    });

    test('recent invoices are newest first and limited to 8', () {
      final inv = c.invoices.value.items;
      expect(inv, isNotEmpty);
      expect(inv.length, lessThanOrEqualTo(8));
      for (var i = 1; i < inv.length; i++) {
        expect(inv[i - 1].date.isBefore(inv[i].date), isFalse);
      }
    });

    test('an unknown serial is reported as not found', () async {
      await c.searchSerial('NOPE-123');
      expect(c.search.value, ReturnSearch.notFound);
    });

    test('a live serial is found without an invoice', () async {
      await c.searchSerial('P02-0001');
      expect(c.search.value, ReturnSearch.found);
      expect(c.lookup.value?.invoice, isNull);
    });

    test(
      'a sold serial needs its product id (invoice chip) and links its invoice',
      () async {
        await c.searchSerial('P01-S001');
        expect(c.search.value, ReturnSearch.notFound);
        await c.searchSerial('P01-S001', productId: 'p01');
        final l = c.lookup.value!;
        expect(l.invoice, isNotNull);
        expect(l.invoice!.serialRefs.map((e) => e.$2), contains('P01-S001'));
      },
    );

    test(
      'returning a sold serial restores it and reverses the whole invoice',
      () async {
        await c.searchSerial('P02-S001', productId: 'p02');
        final lookup = c.lookup.value!;
        final invoice = lookup.invoice!;
        final siblings = [
          for (final (pid, s) in invoice.serialRefs)
            if (s != 'P02-S001') (pid, s),
        ];
        expect(siblings, isNotEmpty); // two serials share an invoice

        await c.submit(found: lookup, isDamaged: false);
        expect(c.notice.value?.message, 'Serial P02-S001 returned to stock');

        // Both serials are back in live stock.
        final dash = Get.find<InventoryDashboardController>();
        await dash.loadReport();
        final live = dash.report.value.items
            .where((r) => r.currentStatus == StockState.inStock)
            .map((r) => r.serialNumber);
        expect(live, contains('P02-S001'));
        expect(live, contains(siblings.first.$2));
        // And the invoice left the recent list.
        expect(c.invoices.value.items.any((i) => i.id == invoice.id), isFalse);
      },
    );

    test(
      'a damaged return archives the serial and removes it from live stock',
      () async {
        await c.searchSerial('P02-0003');
        await c.submit(
          found: c.lookup.value!,
          isDamaged: true,
          reason: '  Water damage ',
        );
        expect(
          c.notice.value?.message,
          'Serial P02-0003 moved to Damaged Inventory',
        );
        final d = c.damaged.value.items.firstWhere(
          (x) => x.serialNumber == 'P02-0003',
        );
        expect(d.reason, 'Water damage');
        final dash = Get.find<InventoryDashboardController>();
        await dash.loadReport();
        expect(
          dash.report.value.items.any((r) => r.serialNumber == 'P02-0003'),
          isFalse,
        );
      },
    );

    test('returning a credit item makes the product Owned', () async {
      await c.searchSerial('P03-0001');
      await c.submit(found: c.lookup.value!, isDamaged: false);
      final list = Get.find<InventoryListController>();
      await list.load(InventoryType.inStock);
      final p = list.inStock.value.items.firstWhere((p) => p.id == 'p03');
      expect(p.ownershipType, OwnershipType.owned);
    });

    test('a second submit while one is running is ignored', () async {
      await c.searchSerial('P02-0003');
      final lookup = c.lookup.value!;
      final a = c.submit(found: lookup, isDamaged: true, reason: 'x');
      final b = c.submit(found: lookup, isDamaged: true, reason: 'x');
      await Future.wait([a, b]);
      await c.loadDamaged();
      expect(
        c.damaged.value.items.where((d) => d.serialNumber == 'P02-0003').length,
        1,
      );
    });
  });

  group('screens', () {
    testWidgets(
      'Damaged page lists records and searches brand/model/serial only',
      (tester) async {
        await _open(tester);
        await tester.tap(find.text('Damaged'));
        await tester.pumpAndSettle();
        expect(find.text('Damaged Inventory'), findsWidgets);
        expect(find.text('2 damaged item(s) archived'), findsOneWidget);
        expect(find.text('P01-0777'), findsOneWidget);
        expect(find.text('P07-0888'), findsOneWidget);

        // Location text is NOT searched (React matches brand, model, serial).
        await tester.enterText(find.byType(TextField).first, 'Dubai Warehouse');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('No damaged inventory records.'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'dahua');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('P07-0888'), findsOneWidget);
        expect(find.text('P01-0777'), findsNothing);
      },
    );

    testWidgets('Deleted page shows who deleted what and opens details', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(find.text('Deleted'));
      await tester.pumpAndSettle();
      expect(
        find.text('Archived records of removed inventory items — read-only'),
        findsOneWidget,
      );
      expect(find.text('Demo Admin'), findsOneWidget);
      expect(find.text('2 deleted records'), findsOneWidget);

      await tester.tap(find.byTooltip('Actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Deleted inventory record'), findsOneWidget);
      expect(find.text('Product details'.toUpperCase()), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'zzz-none');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No matching records'), findsOneWidget);
    });

    testWidgets(
      'Add Stock: validates serials, then saves and returns to the list',
      (tester) async {
        await _open(tester);
        await tester.tap(find.text('Product list'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add stock'));
        await tester.pumpAndSettle();
        expect(find.text('Select a product to continue'), findsOneWidget);

        await tester.tap(find.text('Super Scanner V'));
        await tester.pumpAndSettle();
        expect(find.text('Garrett — Super Scanner V'), findsOneWidget);

        // Two units but only one serial → blocked with React's message.
        await tester.enterText(find.byType(TextFormField).first, '2');
        await tester.pumpAndSettle();
        await tester.enterText(_hint('Serial #1'), 'NEW-1');
        await tester.ensureVisible(find.text('Add 2 Units to Stock'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add 2 Units to Stock'));
        await tester.pumpAndSettle();
        expect(find.text('Please provide 2 serial numbers'), findsOneWidget);

        await tester.enterText(_hint('Serial #2'), 'NEW-2');
        await tester.tap(find.text('Add 2 Units to Stock'));
        await tester.pumpAndSettle();
        expect(find.text('Added 2 units to Super Scanner V'), findsOneWidget);
        // Back on the product list.
        expect(find.text('Total Value'), findsOneWidget);
      },
    );

    testWidgets(
      'Add Returned: choose condition, search, and get a clear not-found message',
      (tester) async {
        await _open(tester);
        await tester.tap(find.text('Add Returned'));
        await tester.pumpAndSettle();
        expect(find.text('Is the returned product damaged?'), findsOneWidget);
        await tester.tap(find.text('Not Damaged'));
        await tester.pumpAndSettle();
        expect(find.text('Condition: Not Damaged'), findsOneWidget);
        expect(find.text('RECENT INVOICES'), findsOneWidget);

        // Empty search is rejected before touching the backend.
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a serial number to search'), findsOneWidget);

        await tester.enterText(_hint('Scan or type serial number'), 'NOPE-1');
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();
        expect(
          find.text('No inventory item found with that serial number.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Add Returned: an invoice serial chip finds the sold unit and returns it',
      (tester) async {
        await _open(tester);
        await tester.tap(find.text('Add Returned'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Not Damaged'));
        await tester.pumpAndSettle();

        final chip = find.textContaining('· Select').first;
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(find.text('Item found'), findsOneWidget);
        expect(find.textContaining('Linked Invoice:'), findsOneWidget);
        expect(
          find.text(
            'This invoice will move to Deleted Invoices when you submit.',
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Return to Stock'));
        await tester.tap(find.text('Return to Stock'));
        await tester.pumpAndSettle();
        expect(find.textContaining('returned to stock'), findsOneWidget);
      },
    );

    testWidgets(
      'Add Returned: damaged flow shows the note box and the recent damaged list',
      (tester) async {
        await _open(tester);
        await tester.tap(find.text('Add Returned'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Damaged').last);
        await tester.pumpAndSettle();
        expect(find.text('Condition: Damaged'), findsOneWidget);
        expect(find.text('DAMAGED INVENTORY (RECENT)'), findsOneWidget);
        expect(find.text('P01-0777'), findsOneWidget);

        await tester.enterText(_hint('Scan or type serial number'), 'P02-0002');
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();
        expect(find.text('Damage Note (optional)'), findsOneWidget);
        expect(find.text('Move to Damaged Inventory'), findsWidgets);

        // Editing the serial discards the stale result.
        await tester.enterText(
          _hint('Scan or type serial number'),
          'P02-0002x',
        );
        await tester.pumpAndSettle();
        expect(find.text('Item found'), findsNothing);
      },
    );

    testWidgets(
      'Inventory Report page: no quick actions, totals or pagination; has download',
      (tester) async {
        await _open(tester);
        // Reach the report through the app's own routing.
        Get.offNamed(AppRoutes.inventoryReport);
        await tester.pumpAndSettle();
        expect(find.text('Inventory Report'), findsWidgets);
        expect(
          find.text('Full per-serial breakdown of every inventory item'),
          findsOneWidget,
        );
        expect(find.text('Add New'), findsNothing);
        expect(find.textContaining('TOTALS'), findsNothing);
        expect(find.textContaining('/ page'), findsNothing);
        expect(find.text('Download'), findsOneWidget);
      },
    );
  });
}
