import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/app/shell/nav_items.dart';
import 'package:bullion_erp/app/shell/side_navigation.dart';
import 'package:bullion_erp/core/settings/currency_provider.dart';
import 'package:bullion_erp/features/accounts/settings/presentation/controllers/settings_controller.dart';
import 'package:bullion_erp/features/admin/user_management/domain/entities/managed_user.dart';
import 'package:bullion_erp/features/admin/user_management/presentation/bindings/user_management_binding.dart';
import 'package:bullion_erp/features/admin/user_management/presentation/controllers/user_management_controller.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:bullion_erp/features/auth/domain/entities/auth_user.dart';
import 'package:bullion_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  resetGet();
  await tester.pumpWidget(BullionApp(initialBinding: Harness.fresh().bindings));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Sign in').last);
  await tester.pumpAndSettle();
}

void main() {
  group('auth controller', () {
    setUp(Harness.install);

    test('login success stores the user', () async {
      final auth = Get.find<AuthController>();
      await auth.login(
        MockAuthDataSource.demoAdminEmail,
        MockAuthDataSource.demoAdminPassword,
      );
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user.value!.isSuperAdmin, isTrue);
    });

    test('wrong password sets an error and no user', () async {
      final auth = Get.find<AuthController>();
      await auth.login(MockAuthDataSource.demoAdminEmail, 'nope');
      expect(auth.isAuthenticated, isFalse);
      expect(auth.error.value, 'Invalid email or password.');
    });

    test('pending account is blocked with the React message', () async {
      final auth = Get.find<AuthController>();
      await auth.login('pending@demo.com', 'pending123');
      expect(auth.error.value, contains('pending admin approval'));
    });

    test('logout clears the session', () async {
      final auth = Get.find<AuthController>();
      await auth.login(
        MockAuthDataSource.demoAdminEmail,
        MockAuthDataSource.demoAdminPassword,
      );
      await auth.logout();
      expect(auth.user.value, isNull);
      expect(auth.status.value, AuthStatus.unauthenticated);
    });
  });

  group('permissions', () {
    const limited = AuthUser(
      uid: 'u',
      email: 'u@x.com',
      role: UserRole.user,
      permissions: [Screens.dashboard, Screens.invoices],
    );

    test('non-admin sees only permitted screens, never user management', () {
      final labels = visibleNavItems(limited).map((i) => i.label).toList();
      expect(labels, ['Dashboard', 'Invoices']);
      expect(limited.canAccess(Screens.userManagement), isFalse);
    });

    test('invoices parent keeps only permitted children', () {
      final invoices = visibleNavItems(limited)
          .firstWhere((i) => i.id == 'invoices');
      expect(invoices.children.map((c) => c.label), ['All Invoices']);
    });

    test('nested path resolves to the longest match', () {
      expect(navItemFor('/invoices/dummy')?.id, 'invoices-dummy');
      expect(navItemFor('/invoices')?.id, 'invoices-all');
    });
  });

  group('login screen', () {
    testWidgets('validates empty form without calling the backend', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('Sign in').last);
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(
        Get.find<AuthController>().status.value,
        AuthStatus.unauthenticated,
      );
    });

    testWidgets('admin login lands on the dashboard with full nav', (
      tester,
    ) async {
      await _pump(tester);
      await _login(
        tester,
        MockAuthDataSource.demoAdminEmail,
        MockAuthDataSource.demoAdminPassword,
      );
      expect(find.textContaining('Welcome back'), findsOneWidget);
      expect(find.text('User Management'), findsWidgets);
    });

    testWidgets(
      'limited user cannot reach user management by URL-style navigation',
      (tester) async {
        await _pump(tester);
        await _login(
          tester,
          MockAuthDataSource.demoUserEmail,
          MockAuthDataSource.demoUserPassword,
        );
        expect(find.text('User Management'), findsNothing);
        expect(find.text('Transactions'), findsNothing);
        // Typing the URL does not help: the route guard sends them back.
        Get.offNamed('/user-management');
        await tester.pumpAndSettle();
        expect(find.text('User management & approvals'), findsNothing);
      },
    );

    testWidgets('wrong credentials show the error banner', (tester) async {
      await _pump(tester);
      await _login(tester, 'admin@demo.com', 'wrong');
      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('mobile width uses a drawer instead of a sidebar', (
      tester,
    ) async {
      await _pump(tester, size: const Size(400, 800));
      await _login(
        tester,
        MockAuthDataSource.demoAdminEmail,
        MockAuthDataSource.demoAdminPassword,
      );
      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Transactions'),
        ),
        findsOneWidget,
      );
    });
  });

  group('user management controller', () {
    late UserManagementController c;

    setUp(() async {
      Harness.install();
      UserManagementBinding().dependencies();
      c = Get.find<UserManagementController>();
      await until(() => c.load.value == UsersLoad.ready);
    });

    test('loads only pending/approved/rejected users, split by status', () {
      expect(c.load.value, UsersLoad.ready);
      expect(c.pending.length, 2);
      expect(c.active.length, 3);
    });

    test(
      'approve moves a pending user to active with the chosen access',
      () async {
        await c.approve(
          uid: 'u-ahmed',
          email: 'ahmed.khan@bullion.com',
          branch: 'dubai',
          permissions: const ['Dashboard'],
        );
        expect(c.pending.length, 1);
        final u = c.active.firstWhere((u) => u.uid == 'u-ahmed');
        expect(u.branch, 'dubai');
        expect(u.permissions, ['Dashboard']);
        expect(c.notice.value?.message, contains('approved successfully'));
      },
    );

    test('reject hides the user from pending and active', () async {
      await c.reject(uid: 'u-sara', email: 'sara.ali@bullion.com');
      expect(c.pending.map((u) => u.uid), ['u-ahmed']);
      expect(
        c.users.firstWhere((u) => u.uid == 'u-sara').status,
        UserStatus.rejected,
      );
    });

    test('delete removes the user', () async {
      await c.deleteUser(uid: 'u-omar', email: 'omar@bullion.com');
      expect(c.users.any((u) => u.uid == 'u-omar'), isFalse);
    });

    test('create rejects a duplicate email and a short password', () async {
      await c.createUser(
        email: 'omar@bullion.com',
        password: 'secret1',
        branch: 'dubai',
        permissions: const ['Dashboard'],
      );
      expect(c.notice.value?.isError, isTrue);
      await c.createUser(
        email: 'new@bullion.com',
        password: '123',
        branch: 'dubai',
        permissions: const ['Dashboard'],
      );
      expect(c.notice.value?.message, 'Password must be at least 6 characters');
    });

    test('create adds an approved user', () async {
      await c.createUser(
        email: 'new@bullion.com',
        password: 'secret1',
        branch: 'chad',
        permissions: const ['Dashboard'],
      );
      expect(c.active.any((u) => u.email == 'new@bullion.com'), isTrue);
      expect(c.notice.value?.tag, 'create');
    });

    test('update access requires at least one permission', () async {
      await c.updateAccess(
        uid: 'u-omar',
        branch: 'dubai',
        permissions: const [],
      );
      expect(c.notice.value?.isError, isTrue);
    });

    test('a repeated tap while busy is ignored (no double submit)', () async {
      final first = c.deleteUser(uid: 'u-omar', email: 'omar@bullion.com');
      final second = c.deleteUser(uid: 'u-omar', email: 'omar@bullion.com');
      await Future.wait([first, second]);
      expect(c.users.any((u) => u.uid == 'u-omar'), isFalse);
      expect(c.notice.value?.isError, isFalse);
    });

    test('currency change is stored and reported', () async {
      final currency = Get.find<CurrencyProvider>();
      await currency.changeCurrency('AED');
      expect(currency.currencyCode.value, 'AED');
      expect(
        Get.find<SettingsController>().notice.value?.message,
        'System currency set to AED',
      );
    });
  });

  group('user management screen', () {
    Future<void> openPage(WidgetTester tester) async {
      await _pump(tester);
      await _login(
        tester,
        MockAuthDataSource.demoAdminEmail,
        MockAuthDataSource.demoAdminPassword,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SideNavigation),
          matching: find.text('User Management'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on pending approvals when requests exist', (
      tester,
    ) async {
      await openPage(tester);
      expect(find.text('User management & approvals'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('Sara Ali'), findsOneWidget);
    });

    testWidgets('approve dialog blocks an empty selection, then approves', (
      tester,
    ) async {
      await openPage(tester);
      await tester.tap(find.text('Approve & set access').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve & grant access'));
      await tester.pumpAndSettle();
      expect(
        find.text('User must have at least one screen permission'),
        findsOneWidget,
      );

      final chip = find.widgetWithText(FilterChip, 'Dashboard');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve & grant access'));
      await tester.pumpAndSettle();
      expect(Get.find<UserManagementController>().pending.length, 1);
      expect(find.textContaining('approved successfully'), findsOneWidget);
    });

    testWidgets('reject asks for confirmation first', (tester) async {
      await openPage(tester);
      await tester.tap(find.text('Reject').first);
      await tester.pumpAndSettle();
      expect(find.text('Reject registration'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(Get.find<UserManagementController>().pending.length, 2);
    });

    testWidgets('add-user form validates before submitting', (tester) async {
      await openPage(tester);
      await tester.tap(find.text('Add new user'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create user'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
      expect(find.text('Please select a branch'), findsOneWidget);
      expect(
        find.text('Please select at least one screen permission'),
        findsOneWidget,
      );
    });

    testWidgets('active users can be searched', (tester) async {
      await openPage(tester);
      await tester.tap(find.textContaining('Active users'));
      await tester.pumpAndSettle();
      expect(find.text('omar@bullion.com'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'lina');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('lina@bullion.com'), findsOneWidget);
      expect(find.text('omar@bullion.com'), findsNothing);
    });
  });
}
