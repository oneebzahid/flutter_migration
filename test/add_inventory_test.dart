import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/core/routes/app_routes.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/catalog.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/add_inventory_rules.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/bindings/inventory_binding.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/create_inventory_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_list_controller.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

EntryRowData _row({
  String brand = 'Garrett',
  String model = 'ATX',
  String category = 'Finished Goods',
  int quantity = 1,
  double cost = 100,
  double sell = 150,
  List<String> serials = const ['S1'],
  String location = 'Dubai',
  bool hasShipment = false,
  bool manual = false,
  int? remaining,
}) => EntryRowData(
  brand: brand,
  model: model,
  category: category,
  quantity: quantity,
  costPrice: cost,
  sellPrice: sell,
  serials: serials,
  location: location,
  hasShipment: hasShipment,
  manualModelInShipment: manual,
  lineRemaining: remaining,
);

NewProductDraft _draft({
  String brand = 'Garrett',
  String model = 'New Model',
  List<String> serials = const ['NEW-1'],
  int quantity = 1,
  double cost = 100,
  double sell = 150,
  OwnershipType own = OwnershipType.owned,
  String? shipmentId,
  String? lineId,
}) => NewProductDraft(
  brandName: brand,
  modelName: model,
  category: 'Finished Goods',
  costPrice: cost,
  sellPrice: sell,
  quantity: quantity,
  location: 'Dubai Warehouse',
  serials: serials,
  ownership: own,
  shipmentId: shipmentId,
  shipmentLineId: lineId,
);

Finder _hint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Future<void> _openForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1700, 1400);
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
  Get.offNamed(AppRoutes.inventoryCreate);
  await tester.pumpAndSettle();
}

void main() {
  group('pricing', () {
    test('suggested retail = landed × (1 + margin%), rounded to 2 dp', () {
      expect(suggestedSellPrice(1200, 25), 1500);
      expect(suggestedSellPrice(800, 25), 1000);
      expect(suggestedSellPrice(333.33, 25), 416.66);
      expect(suggestedSellPrice(1000, 0), 1000);
      expect(suggestedSellPrice(1000, double.nan), 1000);
    });
  });

  group('AddInventoryRules.validate', () {
    test('a complete row is valid', () {
      expect(AddInventoryRules.validate([_row()]).isValid, isTrue);
    });

    test('an empty row lists every required field', () {
      final v = AddInventoryRules.validate([
        _row(
          brand: '',
          model: '',
          category: '',
          cost: 0,
          sell: 0,
          serials: const [''],
          location: '',
        ),
      ]);
      expect(v.rowErrors[0], {
        'brand': 'Required',
        'model': 'Required',
        'category': 'Required',
        'cost': 'Required',
        'retail': 'Required',
        'serials': 'Serial numbers are required',
      });
      expect(v.missingLocation, [0]);
      expect(v.hasSerialProblem, isTrue);
    });

    test('retail below cost is rejected with the cost shown', () {
      final v = AddInventoryRules.validate([_row(cost: 200, sell: 150)]);
      expect(
        v.rowErrors[0]!['retail'],
        'Retail cannot be below the cost of 200.00',
      );
      expect(
        AddInventoryRules.validate([_row(cost: 200, sell: 200)]).isValid,
        isTrue,
      );
    });

    test('serial count and duplicates', () {
      expect(
        AddInventoryRules.validate([
          _row(quantity: 3, serials: const ['A', 'B', '']),
        ]).rowErrors[0]!['serials'],
        'Provide 3 serials (2 filled)',
      );
      expect(
        AddInventoryRules.validate([
          _row(quantity: 1, serials: const ['']),
        ]).rowErrors[0]!['serials'],
        'Serial numbers are required',
      );
      expect(
        AddInventoryRules.validate([
          _row(quantity: 2, serials: const ['A', 'A']),
        ]).rowErrors[0]!['serials'],
        'Duplicate serial numbers',
      );
      expect(
        AddInventoryRules.validate([_row(quantity: 0, serials: const [])])
            .rowErrors[0]!['quantity'],
        'Must be at least 1',
      );
    });

    test('shipment line: too many units is flagged, but "Required" wins when cost is empty', () {
      final over = AddInventoryRules.validate([
        _row(
          hasShipment: true,
          quantity: 3,
          serials: const ['A', 'B', 'C'],
          remaining: 2,
        ),
      ]);
      expect(over.rowErrors[0]!['cost'], 'Only 2 unit(s) remain on this line');
      final noCost = AddInventoryRules.validate([
        _row(
          hasShipment: true,
          quantity: 3,
          serials: const ['A', 'B', 'C'],
          remaining: 2,
          cost: 0,
        ),
      ]);
      expect(noCost.rowErrors[0]!['cost'], 'Required');
    });

    test('a shipment row with no line picked says "Pick a model"', () {
      final v = AddInventoryRules.validate([
        _row(model: '', hasShipment: true),
      ]);
      expect(v.rowErrors[0]!['model'], 'Pick a model');
      final manual = AddInventoryRules.validate([
        _row(model: '', hasShipment: true, manual: true),
      ]);
      expect(manual.rowErrors[0]!['model'], 'Required');
    });

    test('errors are keyed by row and locations are reported per row', () {
      final v = AddInventoryRules.validate([
        _row(),
        _row(location: ''),
        _row(brand: ''),
      ]);
      expect(v.rowErrors.keys, [2]);
      expect(v.missingLocation, [1]);
    });

    test('grand total = cost × (filled serials, else quantity)', () {
      expect(
        AddInventoryRules.grandTotal([
          _row(cost: 100, quantity: 2, serials: const ['A', 'B']),
          _row(cost: 50, quantity: 3, serials: const ['', '', '']),
        ]),
        350,
      );
    });
  });

  group('creating products', () {
    late CreateInventoryController c;
    late InventoryListController list;

    setUp(() async {
      Harness.install();
      InventoryBinding().dependencies();
      c = Get.find<CreateInventoryController>();
      list = Get.find<InventoryListController>();
      await c.loadShipments();
    });

    test('saves a product; stock is the number of filled serials', () async {
      await c.createProducts([
        _draft(serials: const ['N-1', 'N-2', ' '], quantity: 3),
      ]);
      expect(c.notice.value?.message, '1 product added to inventory');
      expect(c.notice.value?.tag, 'create-ok');
      await list.load(InventoryType.inStock);
      final p = list.inStock.value.items.firstWhere(
        (p) => p.modelName == 'New Model',
      );
      expect(p.stock, 2);
      expect(p.serialNumbers, ['N-1', 'N-2']);
      expect(p.serialCities['N-1'], 'Dubai Warehouse');
      expect(p.ownershipType, OwnershipType.owned);
    });

    test('credit stock records the supplier cost as unpaid', () async {
      await c.createProducts([
        _draft(own: OwnershipType.credit, cost: 500, sell: 700),
      ]);
      await list.load(InventoryType.inStock);
      final p = list.inStock.value.items.firstWhere(
        (p) => p.modelName == 'New Model',
      );
      expect(p.ownershipType, OwnershipType.credit);
      expect(p.supplierCost, 500);
      expect(p.supplierPaymentStatus, SupplierPaymentStatus.unpaid);
    });

    test('a serial already used by any product is rejected', () async {
      await c.createProducts([
        _draft(serials: const ['P01-0001']),
      ]);
      expect(c.notice.value?.isError, isTrue);
      expect(
        c.notice.value?.message,
        startsWith('Duplicate serial number: P01-0001'),
      );
    });

    test('the duplicate check ignores case and surrounding spaces', () async {
      await c.createProducts([
        _draft(serials: const [' p01-0001 ']),
      ]);
      expect(c.notice.value?.isError, isTrue);
    });

    test('an exact repeat of a product is rejected', () async {
      final d = _draft(serials: const ['X-1']);
      await c.createProducts([d]);
      // Same details but the serial is now taken -> serial message wins first.
      await c.createProducts([d]);
      expect(c.notice.value?.isError, isTrue);
    });

    test(
      'shipment line: units come off the line and over-stocking is refused',
      () async {
        final line = c.shipments.value.items
            .firstWhere((s) => s.id == 'sh1')
            .lines
            .first;
        expect(line.remaining, 10);
        await c.createProducts([
          _draft(
            brand: 'Nokta',
            model: 'Legend',
            serials: const ['L-1', 'L-2'],
            quantity: 2,
            shipmentId: 'sh1',
            lineId: 'sh1-a',
          ),
        ]);
        await c.loadShipments();
        final after = c.shipments.value.items
            .firstWhere((s) => s.id == 'sh1')
            .lines
            .first;
        expect(after.remaining, 8);
        expect(after.stocked, 2);

        await c.createProducts([
          _draft(
            brand: 'Nokta',
            model: 'Legend',
            serials: [for (var i = 0; i < 9; i++) 'Z-$i'],
            quantity: 9,
            shipmentId: 'sh1',
            lineId: 'sh1-a',
          ),
        ]);
        expect(
          c.notice.value?.message,
          startsWith('Only 8 unit(s) remain on this line'),
        );
      },
    );

    test(
      'stop-on-error keeps earlier rows saved and says so (no rollback)',
      () async {
        await c.createProducts([
          _draft(model: 'Good One', serials: const ['G-1']),
          _draft(model: 'Bad One', serials: const ['P01-0001']),
          _draft(model: 'Never Reached', serials: const ['R-1']),
        ]);
        final n = c.notice.value!;
        expect(n.tag, 'create-fail');
        expect(n.message, contains('1 product saved before the error.'));
        await list.load(InventoryType.inStock);
        final models = list.inStock.value.items.map((p) => p.modelName);
        expect(models, contains('Good One'));
        expect(models, isNot(contains('Never Reached')));
      },
    );

    test('continue-on-error (multi-model) reports a partial save', () async {
      await c.createProducts([
        _draft(model: 'Good', serials: const ['G-9']),
        _draft(model: 'Bad', serials: const ['P01-0001']),
      ], continueOnError: true);
      expect(c.notice.value?.tag, 'create-partial');
      expect(c.notice.value?.message, 'Saved 1, but 1 failed: Garrett Bad');
    });

    test('new brands and models are remembered', () async {
      await c.createProducts([
        _draft(brand: 'Brand New Co', model: 'Alpha', serials: const ['BN-1']),
      ]);
      await c.loadBrands();
      await c.loadModels('Brand New Co');
      expect(c.brands.value.items, contains('Brand New Co'));
      expect(
        c.modelsFor('Brand New Co').items.map((m) => m.name),
        contains('Alpha'),
      );
    });

    test(
      'brand list has no duplicates and is sorted; txn ids increase',
      () async {
        await c.loadBrands();
        await c.loadTxnId();
        final b = c.brands.value.items;
        expect(b.toSet().length, b.length);
        expect([...b]..sort(), b);
        final first = c.txnId.value;
        await c.loadTxnId();
        expect(c.txnId.value, isNot(first));
      },
    );

    test('a second save while one is running is ignored', () async {
      final a = c.createProducts([
        _draft(model: 'Once', serials: const ['O-1']),
      ]);
      final b = c.createProducts([
        _draft(model: 'Once', serials: const ['O-1']),
      ]);
      await Future.wait([a, b]);
      await list.load(InventoryType.inStock);
      expect(
        list.inStock.value.items.where((p) => p.modelName == 'Once').length,
        1,
      );
    });
  });

  group('Add Inventory screen', () {
    testWidgets('opens with Owned selected, a shipment picker and a TXN id', (
      tester,
    ) async {
      await _openForm(tester);
      expect(find.text('Add Inventory'), findsWidgets);
      expect(find.text('TXN: TXN-000123'), findsOneWidget);
      expect(find.text('Owned Inventory'), findsOneWidget);
      expect(find.text('Third-party Inventory'), findsOneWidget);
      expect(find.text('Shipment'), findsOneWidget);
      expect(find.text('Purchasing Cost (PKR) *'), findsOneWidget);
    });

    testWidgets('Credit hides the shipment card and relabels the cost', (
      tester,
    ) async {
      await _openForm(tester);
      await tester.tap(find.text('Third-party Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Shipment'), findsNothing);
      expect(find.text('Supplier Cost (PKR) *'), findsOneWidget);
      expect(
        find.textContaining('appear in Inventory Payables'),
        findsOneWidget,
      );
    });

    testWidgets(
      'saving an empty form shows inline errors and the location message',
      (tester) async {
        await _openForm(tester);
        await tester.ensureVisible(find.text('Save Inventory'));
        await tester.tap(find.text('Save Inventory'));
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsWidgets);
        expect(
          find.textContaining('Product 1: location is required'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Fix serial-number errors before saving'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'picking a shipment line fills landed cost, suggested retail and the breakdown',
      (tester) async {
        await _openForm(tester);
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SHP-001 · Nokta · ABC Trading').last);
        await tester.pumpAndSettle();
        // Brand is fixed to the shipment's brand.
        expect(find.text('Nokta'), findsWidgets);

        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Legend — 10 remaining').last);
        await tester.pumpAndSettle();
        expect(find.text('10 units left on this shipment'), findsOneWidget);
        expect(find.text('Cost Breakdown — per unit'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, '1200'),
          findsOneWidget,
        ); // landed cost
        expect(find.widgetWithText(TextField, '1500'), findsOneWidget); // +25%

        // Changing the margin re-prices the row.
        await tester.enterText(find.widgetWithText(TextField, '25'), '50');
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, '1800.00'), findsOneWidget);
      },
    );

    testWidgets(
      'a hand-entered (Credit) product saves and returns to Inventory',
      (tester) async {
        await _openForm(tester);
        await tester.tap(find.text('Third-party Inventory'));
        await tester.pumpAndSettle();

        await tester.enterText(_hint('Type brand…'), 'Garrett');
        await tester.pumpAndSettle();
        await tester.enterText(_hint('Type model…'), 'Fresh Model');
        await tester.pumpAndSettle();

        // Dropdown order in Credit mode: category, location, condition.
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finished Goods').last);
        await tester.pumpAndSettle();

        await tester.enterText(_hint('0.00').at(0), '100');
        await tester.enterText(_hint('0.00').at(1), '150');
        await tester.enterText(_hint('Serial #1'), 'FRESH-001');

        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<String>).at(1),
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dubai Warehouse').last);
        await tester.pumpAndSettle();

        expect(find.textContaining('Subtotal:'), findsOneWidget);
        await tester.ensureVisible(find.text('Save Inventory'));
        await tester.tap(find.text('Save Inventory'));
        await tester.pumpAndSettle();
        expect(find.text('1 product added to inventory'), findsOneWidget);
        // Back on the Inventory dashboard.
        expect(
          find.text(
            'Per-serial inventory with sales, costs and payment tracking',
          ),
          findsOneWidget,
        );

        // Repository calls use real timers: run them outside the fake clock.
        final list = Get.find<InventoryListController>();
        await tester.runAsync(() => list.load(InventoryType.inStock));
        final p = list.inStock.value.items.firstWhere(
          (p) => p.modelName == 'Fresh Model',
        );
        expect(p.ownershipType, OwnershipType.credit);
        expect(p.supplierCost, 100);
      },
    );

    testWidgets(
      'rows can be added and removed; the button says how many will save',
      (tester) async {
        await _openForm(tester);
        expect(find.text('Save Inventory'), findsOneWidget);
        await tester.ensureVisible(find.text('Add Another Product'));
        await tester.tap(find.text('Add Another Product'));
        await tester.pumpAndSettle();
        expect(find.text('Product #1'), findsOneWidget);
        expect(find.text('Product #2'), findsOneWidget);
        expect(find.text('Save All 2 Products'), findsOneWidget);
        await tester.tap(find.text('Remove').last);
        await tester.pumpAndSettle();
        expect(find.text('Save Inventory'), findsOneWidget);
        expect(
          find.text('Remove'),
          findsNothing,
        ); // the last row cannot be removed
      },
    );
  });
}
