import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/app/shell/nav_items.dart';
import 'package:bullion_erp/core/state/loadable.dart';
import 'package:bullion_erp/core/widgets/app_pagination_bar.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/inventory_records.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/inventory_report_row.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/inventory_filters.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/report_filters.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/bindings/inventory_binding.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_dashboard_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_list_controller.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

/// Drags the page's own list to its end so lazily built bottom widgets exist.
Future<void> _scrollPageToBottom(WidgetTester tester) async {
  // Start above the table so the page (not the table) scrolls.
  await tester.dragFrom(const Offset(900, 100), const Offset(0, -3000));
  await tester.pumpAndSettle();
}

InventoryReportRow _row(
  String brand,
  String model,
  String serial, {
  DateTime? date,
  String type = 'T',
  String location = 'L',
  OwnershipType? own = OwnershipType.owned,
  StockState state = StockState.inStock,
}) => InventoryReportRow(
  productId: 'p-$brand',
  brandName: brand,
  modelName: model,
  serialNumber: serial,
  type: type,
  location: location,
  ownership: own,
  condition: 'New',
  currentStatus: state,
  stockInDateAuto: date,
);

Future<void> _openInventory(
  WidgetTester tester, {
  String email = MockAuthDataSource.demoAdminEmail,
  String password = MockAuthDataSource.demoAdminPassword,
}) async {
  tester.view.physicalSize = const Size(1700, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  resetGet();
  await tester.pumpWidget(BullionApp(initialBinding: Harness.fresh().bindings));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Sign in').last);
  await tester.pumpAndSettle();
}

InventoryDashboardController get _dashboard =>
    Get.find<InventoryDashboardController>();

void main() {
  group('report filters', () {
    final d = DateTime(2026, 10, 3);
    final rows = [
      _row('Garrett', 'A', '1', date: d),
      _row('Garrett', 'B', '2', date: d.add(const Duration(days: 2))),
      _row('Minelab', 'C', '3', date: d.add(const Duration(days: 1))),
      _row('Dahua', 'D', '4'),
    ];

    test('OR within a group, AND across groups', () {
      var f = const ReportFilters(brands: {'Garrett', 'Minelab'});
      expect(f.apply(rows).length, 3);
      f = f.copyWith(models: {'C'});
      expect(f.apply(rows).map((r) => r.serialNumber), ['3']);
    });

    test('sorts newest stock-in first, undated rows last', () {
      final out = ReportFilters.empty.apply(rows);
      expect(out.map((r) => r.serialNumber), ['2', '3', '1', '4']);
    });

    test('"to" date is inclusive to end of day', () {
      final f = ReportFilters(dateTo: d.add(const Duration(days: 1)));
      final out = f.apply([
        _row('G', 'A', '1', date: d.add(const Duration(days: 1, hours: 20))),
        _row('G', 'A', '2', date: d.add(const Duration(days: 2))),
      ]);
      expect(out.map((r) => r.serialNumber), ['1']);
    });

    test('rows without a date never match a date filter', () {
      expect(
        ReportFilters(dateFrom: d)
            .apply(rows)
            .any((r) => r.serialNumber == '4'),
        isFalse,
      );
    });

    test('search is not counted as an active filter', () {
      expect(const ReportFilters(search: 'abc').activeCount, 0);
      expect(const ReportFilters(search: 'x', brands: {'a'}).activeCount, 1);
    });

    test('search covers serial and invoice text', () {
      final r = InventoryReportRow(
        productId: 'p',
        brandName: 'B',
        modelName: 'M',
        serialNumber: 'SN-777',
        type: 'T',
        condition: 'New',
        currentStatus: StockState.sold,
        invoiceNumber: 'INV-9',
      );
      expect(const ReportFilters(search: 'sn-777').matches(r), isTrue);
      expect(const ReportFilters(search: 'inv-9').matches(r), isTrue);
      expect(const ReportFilters(search: 'zzz').matches(r), isFalse);
    });
  });

  group('product stats and filters', () {
    Product p(String id, double cost, int stock, ProductStatus s) => Product(
      id: id,
      brandName: 'B',
      modelName: 'M',
      category: 'C',
      sellPrice: cost * 2,
      buyType: BuyType.import,
      warrantyYears: 1,
      serialNumbers: [for (var i = 0; i < stock; i++) '$id-$i'],
      status: s,
      costPrice: cost,
    );

    test('total value is cost × stock (not sell price)', () {
      final s = ProductStats.of([
        p('1', 100, 2, ProductStatus.available),
        p('2', 50, 4, ProductStatus.inTransit),
      ]);
      expect(s.totalValue, 400);
      expect(s.totalStock, 6);
      expect(s.inTransit, 1);
      expect(s.available, 1);
    });

    test('hasStock filter', () {
      final list = [
        p('1', 1, 0, ProductStatus.sold),
        p('2', 1, 3, ProductStatus.available),
      ];
      expect(const ProductFilters(hasStock: true).apply(list).single.id, '2');
      expect(const ProductFilters(hasStock: false).apply(list).single.id, '1');
    });
  });

  test('pagination slices and clamps', () {
    const s = PageState(page: 99, pageSize: 10);
    final all = List.generate(25, (i) => i);
    expect(s.pageCount(25), 3);
    expect(s.safePage(25), 3);
    expect(s.slice(all), [20, 21, 22, 23, 24]);
    expect(const PageState().slice(<int>[]), isEmpty);
  });

  test('route permissions use the most specific route', () {
    expect(requiredScreenFor('/inventory'), 'Inventory Dashboard');
    expect(requiredScreenFor('/inventory/view'), 'Inventory View');
    expect(
      requiredScreenFor('/inventory/create-new/costing'),
      'Inventory Type Selection',
    );
    expect(
      requiredScreenFor('/product-transfer/new'),
      'Create Product Transfer',
    );
  });

  group('inventory controllers', () {
    setUp(() {
      Harness.install();
      InventoryBinding().dependencies();
    });

    test('report rows load', () async {
      final c = _dashboard;
      await until(() => c.report.value.status == LoadStatus.ready);
      expect(c.report.value.items, isNotEmpty);
      expect(
        c.report.value.items.any((r) => r.currentStatus == StockState.sold),
        isTrue,
      );
    });

    test('deleting one serial reports the React message and drops the row', () async {
      final c = _dashboard;
      await until(() => c.report.value.status == LoadStatus.ready);
      final r = c.report.value.items.firstWhere((r) => r.productId == 'p02');
      final before = c.report.value.items.length;
      await c.deleteSerials([
        SerialRef(
          productId: r.productId,
          serial: r.serialNumber,
          brand: r.brandName,
          model: r.modelName,
        ),
      ]);
      expect(c.report.value.items.length, before - 1);
      expect(
        c.notice.value?.message,
        'Serial ${r.serialNumber} of ${r.brandName} ${r.modelName} moved to Deleted Inventory',
      );
    });

    test('deleting the last serial removes the parent product', () async {
      final list = Get.find<InventoryListController>();
      await list.load(InventoryType.inStock);
      final target = list.inStock.value.items.firstWhere((p) => p.stock == 2);
      final c = _dashboard;
      await c.deleteSerials([
        for (final s in target.serialNumbers)
          SerialRef(
            productId: target.id,
            serial: s,
            brand: target.brandName,
            model: target.modelName,
          ),
      ]);
      await list.load(InventoryType.inStock);
      expect(list.inStock.value.items.any((p) => p.id == target.id), isFalse);
      expect(c.notice.value?.message, '2 serials moved to Deleted Inventory');
    });

    test('a partial failure is reported with counts', () async {
      final c = _dashboard;
      await until(() => c.report.value.status == LoadStatus.ready);
      final r = c.report.value.items.first;
      await c.deleteSerials([
        SerialRef(
          productId: r.productId,
          serial: r.serialNumber,
          brand: r.brandName,
          model: r.modelName,
        ),
        const SerialRef(productId: 'nope', serial: 'x', brand: 'b', model: 'm'),
      ]);
      expect(c.notice.value?.isError, isTrue);
      expect(c.notice.value?.message, 'Deleted 1, 1 failed — check console.');
    });

    test(
      'in-stock list excludes pending receivables; on-order shows them',
      () async {
        final list = Get.find<InventoryListController>();
        await list.load(InventoryType.inStock);
        await list.load(InventoryType.onOrder);
        expect(
          list.inStock.value.items.any(
            (p) => p.receivableStatus == ReceivableStatus.pending,
          ),
          isFalse,
        );
        expect(list.onOrder.value.items.length, 3);
      },
    );

    test(
      'receiving an on-order product moves it out of the on-order list',
      () async {
        final list = Get.find<InventoryListController>();
        await list.load(InventoryType.onOrder);
        final id = list.onOrder.value.items.first.id;
        await list.receiveProduct(id);
        expect(list.onOrder.value.items.any((p) => p.id == id), isFalse);
        expect(
          list.notice.value?.message,
          'Product moved to stock successfully',
        );
      },
    );

    test('a second delete while one is running is ignored', () async {
      final list = Get.find<InventoryListController>();
      await list.load(InventoryType.onOrder);
      final id = list.onOrder.value.items.first.id;
      final a = list.receiveProduct(id);
      final b = list.receiveProduct(id);
      await Future.wait([a, b]);
      expect(list.notice.value?.isError, isFalse);
    });
  });

  group('inventory screens', () {
    testWidgets('dashboard shows the per-serial table, count and totals', (
      tester,
    ) async {
      await _openInventory(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(Scaffold).first,
              matching: find.text('Inventory'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Per-serial inventory with sales, costs and payment tracking',
        ),
        findsOneWidget,
      );
      expect(find.text('STOCK-IN DATE (AUTO)'), findsOneWidget);
      // The totals footer is sticky inside the table, so no page scroll needed.
      expect(find.textContaining('TOTALS — ALL'), findsOneWidget);
      expect(find.text('Add New'), findsOneWidget);
    });

    testWidgets(
      'wide table has an always-visible pinned horizontal scrollbar',
      (tester) async {
        await _openInventory(tester);
        await tester.tap(find.text('Inventory').first);
        await tester.pumpAndSettle();
        // Standard: every table shows a visible horizontal scrollbar plus a
        // "more columns" arrow when it is wider than the screen.
        final bar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
        expect(bar.controller, isNotNull);
        final themed = tester.widget<ScrollbarTheme>(
          find
              .ancestor(
                of: find.byType(Scrollbar).first,
                matching: find.byType(ScrollbarTheme),
              )
              .first,
        );
        expect(themed.data.thumbVisibility?.resolve({}), isTrue);
        expect(themed.data.trackVisibility?.resolve({}), isTrue);
        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      },
    );

    testWidgets(
      'dashboard row menu offers View details and Delete (with confirm)',
      (tester) async {
        await _openInventory(tester);
        await tester.tap(find.text('Inventory').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Actions').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View details'));
        await tester.pumpAndSettle();
        expect(find.text('Serial No.'), findsWidgets);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Actions').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete this item?'), findsOneWidget);
        final before = _dashboard.report.value.items.length;
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(_dashboard.report.value.items.length, before);
      },
    );

    testWidgets('select all then bulk delete asks for confirmation', (
      tester,
    ) async {
      await _openInventory(tester);
      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('selected of'), findsOneWidget);
      await tester.tap(find.textContaining('Delete ('));
      await tester.pumpAndSettle();
      expect(find.text('Delete selected items?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_dashboard.report.value.items.length, greaterThan(20));
    });

    testWidgets(
      'a user without Inventory Dashboard permission cannot open it',
      (tester) async {
        // user@demo.com has Dashboard, Inventory Dashboard and Invoices List.
        await _openInventory(
          tester,
          email: MockAuthDataSource.demoUserEmail,
          password: MockAuthDataSource.demoUserPassword,
        );
        await tester.tap(find.text('Inventory').first);
        await tester.pumpAndSettle();
        // Quick actions for screens the user lacks are hidden.
        expect(find.text('Add New'), findsNothing);
        expect(find.text('Deleted'), findsNothing);
      },
    );

    testWidgets('product list shows KPIs, summary and opens details', (
      tester,
    ) async {
      await _openInventory(tester);
      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product list'));
      await tester.pumpAndSettle();
      expect(find.text('Total Value'), findsOneWidget);
      // Row menu (⋮) with labelled items.
      await tester.tap(find.byTooltip('Actions').first);
      await tester.pumpAndSettle();
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Product details'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await _scrollPageToBottom(tester);
      expect(find.textContaining('Sum of'), findsOneWidget);
    });

    testWidgets('product list search narrows the rows', (tester) async {
      await _openInventory(tester);
      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product list'));
      await tester.pumpAndSettle();
      final before = find.byTooltip('Actions').evaluate().length;
      await tester.enterText(find.byType(TextField).first, 'Minelab');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final after = find.byTooltip('Actions').evaluate().length;
      expect(after, lessThan(before));
      expect(after, greaterThan(0));
    });
  });
}
