// Visual audit tool (not part of the normal test run): renders screens to PNG
// with real fonts so layout / spacing problems can be inspected.
//
//   flutter test test_shots/shots_test.dart --dart-define=SHOT_DIR=<folder>
//
// Fonts come from the Flutter SDK (Roboto + Material icons).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/core/di/initial_bindings.dart';
import 'package:bullion_erp/features/accounts/inventory/data/datasources/mock_inventory_datasource.dart';
import 'package:bullion_erp/features/accounts/settings/data/datasources/mock_settings_datasource.dart';
import 'package:bullion_erp/features/admin/user_management/data/datasources/mock_user_datasource.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR', defaultValue: 'shots_out');
const _fonts = 'C:/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String f) async => ByteData.sublistView(
    Uint8List.fromList(await File('$_fonts/$f').readAsBytes()),
  );
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('roboto-regular.ttf'))
    ..addFont(bytes('roboto-medium.ttf'))
    ..addFont(bytes('roboto-bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}

final _key = GlobalKey();

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_shotDir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester t) async {
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } catch (_) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _go(WidgetTester t, String path) async {
  Get.offNamed(path);
  await _settle(t);
}

void main() {
  setUpAll(_loadFonts);

  Future<void> boot(WidgetTester t, Size size, {bool login = true}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.testMode = true;
    Get.reset();
    await t.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: BullionApp(
          initialBinding: InitialBindings(
            authDataSource: MockAuthDataSource(latency: Duration.zero),
            userDataSource: MockUserDataSource(latency: Duration.zero),
            settingsDataSource: MockSettingsDataSource(latency: Duration.zero),
            inventoryDataSource: MockInventoryDataSource(
              latency: Duration.zero,
            ),
          ),
        ),
      ),
    );
    await _settle(t);
    if (!login) return;
    await t.enterText(
      find.byType(TextFormField).at(0),
      MockAuthDataSource.demoAdminEmail,
    );
    await t.enterText(
      find.byType(TextFormField).at(1),
      MockAuthDataSource.demoAdminPassword,
    );
    await t.tap(find.text('Sign in').last);
    await _settle(t);
  }

  const desktop = Size(1440, 900);
  const mobile = Size(390, 844);

  const routes = <String, String>{
    'dashboard': '/dashboard',
    'users': '/user-management',
    'inv': '/inventory',
    'inv_list': '/inventory/view',
    'inv_report': '/inventory/report',
    'inv_damaged': '/inventory/damaged',
    'inv_deleted': '/inventory/deleted',
    'inv_addstock': '/inventory/add-existing',
    'inv_returned': '/inventory/add-returned',
    'inv_add': '/inventory/create-new',
  };

  testWidgets('login desktop', (t) async {
    await boot(t, desktop, login: false);
    await _snap(t, 'desktop_login');
  });
  testWidgets('login mobile', (t) async {
    await boot(t, mobile, login: false);
    await _snap(t, 'mobile_login');
  });

  for (final e in routes.entries) {
    testWidgets('${e.key} desktop', (t) async {
      await boot(t, desktop);
      await _go(t, e.value);
      await _snap(t, 'desktop_${e.key}');
    });
    testWidgets('${e.key} mobile', (t) async {
      await boot(t, mobile);
      await _go(t, e.value);
      await _snap(t, 'mobile_${e.key}');
    });
  }
}
