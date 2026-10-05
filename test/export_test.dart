import 'dart:typed_data';

import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_dashboard_controller.dart';
import 'package:bullion_erp/core/utils/file_downloader.dart';
import 'package:bullion_erp/core/utils/table_export.dart';
import 'package:bullion_erp/core/widgets/export_menu.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

class _Saved {
  _Saved(this.name, this.ext, this.bytes);
  final String name;
  final String ext;
  final Uint8List bytes;
}

class _FakeDownloader implements FileDownloader {
  final saved = <_Saved>[];

  @override
  Future<void> save({
    required String fileName,
    required String extension,
    required Uint8List bytes,
  }) async => saved.add(_Saved(fileName, extension, bytes));
}

const _table = ExportTable(
  title: 'Inventory: Q4 / [test]',
  subtitle: '2 records',
  headers: ['Brand', 'Serial No.', 'Cost (PKR)'],
  rightAlignedColumns: {2},
  rows: [
    ['Garrett', 'SN-1', 1250.5],
    ['Minelab — Pro', 'SN-2', null],
  ],
);

void main() {
  late _FakeDownloader fake;
  setUp(() {
    fake = _FakeDownloader();
    AppFileDownloader.instance = fake;
  });
  tearDown(() => AppFileDownloader.instance = const PlatformFileDownloader());

  group('TableExport', () {
    test('xlsx has a header row, data rows and numeric cells', () {
      final book = Excel.decodeBytes(TableExport.toXlsx(_table));
      final sheet = book.tables.values.first;
      expect(sheet.rows.length, 3);
      expect(sheet.rows[0].map((c) => c?.value.toString()), [
        'Brand',
        'Serial No.',
        'Cost (PKR)',
      ]);
      expect(sheet.rows[1][0]?.value.toString(), 'Garrett');
      expect(sheet.rows[1][2]?.value, isA<DoubleCellValue>());
      // Blank, not the text "null".
      expect(sheet.rows[2][2]?.value, isNull);
    });

    test('sheet name is made safe for Excel', () {
      final book = Excel.decodeBytes(TableExport.toXlsx(_table));
      final name = book.tables.keys.first;
      expect(name.length, lessThanOrEqualTo(31));
      expect(name.contains(RegExp(r'[\[\]:*?/\\]')), isFalse);
    });

    test('pdf is a real PDF and survives non-Latin punctuation', () async {
      final bytes = await TableExport.toPdf(_table);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('pdf handles hundreds of rows over many pages', () async {
      final big = ExportTable(
        title: 'Big',
        headers: [for (var i = 0; i < 15; i++) 'Col $i'],
        rows: [
          for (var r = 0; r < 300; r++)
            [for (var c = 0; c < 15; c++) 'r$r-c$c'],
        ],
      );
      final bytes = await TableExport.toPdf(big);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('ExportMenu', () {
    Future<void> pump(WidgetTester tester, {bool enabled = true}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ExportMenu(
                  spec: ExportSpec(
                    fileBaseName: 'inventory',
                    rowCount: enabled ? 1 : 0,
                    build: () => _table,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('Excel choice downloads an .xlsx named with today\'s date', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excel (.xlsx)'));
      await tester.pumpAndSettle();
      expect(fake.saved.single.ext, 'xlsx');
      expect(
        fake.saved.single.name,
        matches(RegExp(r'^inventory-\d{4}-\d{2}-\d{2}$')),
      );
      expect(fake.saved.single.bytes, isNotEmpty);
      expect(find.text('Downloaded 2 rows as Excel'), findsOneWidget);
    });

    testWidgets('PDF choice downloads a .pdf', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('PDF (.pdf)'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(fake.saved.single.ext, 'pdf');
      expect(find.text('Downloaded 2 rows as PDF'), findsOneWidget);
    });

    testWidgets('is disabled when there is nothing to export', (tester) async {
      await pump(tester, enabled: false);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('a failing downloader shows an error, not a crash', (
      tester,
    ) async {
      AppFileDownloader.instance = _Failing();
      await pump(tester);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excel (.xlsx)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not create the Excel file'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'dashboard exports every filtered row, not just the visible page',
    (tester) async {
      tester.view.physicalSize = const Size(1700, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      resetGet();
      await tester.pumpWidget(
        BullionApp(initialBinding: Harness.fresh().bindings),
      );
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

      final total =
          Get.find<InventoryDashboardController>().report.value.items.length;
      expect(total, greaterThan(25)); // more than one page of 25

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excel (.xlsx)'));
      await tester.pumpAndSettle();

      final book = Excel.decodeBytes(fake.saved.single.bytes);
      final rows = book.tables.values.first.rows;
      final text = [
        for (final r in rows) r.map((c) => c?.value?.toString() ?? '').toList(),
      ];
      expect(text.first.first, 'BULLION'); // letterhead metadata
      expect(text.any((r) => (r.first).startsWith('Generated:')), isTrue);
      final headerAt = text.indexWhere(
        (r) => r.first == 'Stock-In Date (Auto)',
      );
      expect(headerAt, greaterThan(0));
      expect(rows.length - headerAt - 1, total); // every row, all pages
      expect(rows[headerAt].length, 15);
      expect(fake.saved.single.name, startsWith('inventory-'));
    },
  );
}

class _Failing implements FileDownloader {
  @override
  Future<void> save({
    required String fileName,
    required String extension,
    required Uint8List bytes,
  }) async => throw Exception('disk full');
}
