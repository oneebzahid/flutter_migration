import 'package:bullion_erp/app/app.dart';
import 'package:bullion_erp/core/routes/app_routes.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/supplier_payment.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/rules/payable_rules.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/bindings/inventory_binding.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/inventory_payables_controller.dart';
import 'package:bullion_erp/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

Product _p({
  String id = 'x',
  OwnershipType? own = OwnershipType.credit,
  double? cost = 1000,
  double? paid = 0,
  SupplierPaymentStatus? status = SupplierPaymentStatus.unpaid,
  int stock = 0,
}) => Product(
  id: id,
  brandName: 'Garrett',
  modelName: 'ATX',
  category: 'C',
  sellPrice: 1,
  buyType: BuyType.import,
  warrantyYears: 1,
  status: ProductStatus.available,
  ownershipType: own,
  supplierCost: cost,
  supplierPaidAmount: paid,
  supplierPaymentStatus: status,
  serialNumbers: [for (var i = 0; i < stock; i++) '$id-$i'],
);

void main() {
  group('PayableRules', () {
    test(
      'credit stock with a balance is payable; owned and cleared are not',
      () {
        expect(PayableRules.isPayable(_p()), isTrue);
        expect(PayableRules.isPayable(_p(own: OwnershipType.owned)), isFalse);
        expect(
          PayableRules.isPayable(
            _p(paid: 1000, status: SupplierPaymentStatus.cleared),
          ),
          isFalse,
        );
        // React: a "Cleared" item that still shows a balance stays listed.
        expect(
          PayableRules.isPayable(
            _p(paid: 400, status: SupplierPaymentStatus.cleared),
          ),
          isTrue,
        );
      },
    );

    test(
      'totals: sold-out = due now, in stock = still to come; no search effect',
      () {
        final t = PayableRules.totals([
          _p(id: 'a', cost: 1000, paid: 400), // sold out, 600 due
          _p(id: 'b', cost: 500, paid: 0, stock: 2), // in stock, 500 later
          _p(id: 'c', cost: 300, paid: 300), // sold out, nothing owed
        ]);
        expect(t.dueNow, 600);
        expect(t.stillInStock, 500);
      },
    );

    test('search matches brand or model, case-insensitively', () {
      expect(PayableRules.matches(_p(), 'garr'), isTrue);
      expect(PayableRules.matches(_p(), 'atx'), isTrue);
      expect(PayableRules.matches(_p(), 'zzz'), isFalse);
      expect(PayableRules.matches(_p(), '  '), isTrue);
    });

    test('guards: overpayment, zero, missing cost and missing bank', () {
      final p = _p(cost: 1000, paid: 900);
      String? v(
        double a, {
        PaymentChannel c = PaymentChannel.cash,
        String? bank,
      }) => PayableRules.validate(
        product: p,
        amount: a,
        channel: c,
        bankId: bank,
      );
      expect(v(100), isNull);
      expect(v(100.01), contains('exceeds the outstanding balance'));
      expect(v(0), isNotNull);
      expect(
        PayableRules.validate(
          product: _p(cost: null),
          amount: 10,
          channel: PaymentChannel.cash,
          bankId: null,
        ),
        contains('cost is required'),
      );
      expect(v(50, c: PaymentChannel.bank), 'Please select a bank account');
      expect(v(50, c: PaymentChannel.bank, bank: 'b1'), isNull);
    });
  });

  group('payables controller', () {
    late InventoryPayablesController c;

    setUp(() async {
      Harness.install();
      InventoryBinding().dependencies();
      c = Get.find<InventoryPayablesController>();
      await until(() => c.payables.value.items.isNotEmpty);
    });

    Product target() =>
        c.payables.value.items.firstWhere((p) => p.supplierOutstanding > 1000);

    test('lists only credit stock that is still owed', () {
      expect(c.payables.value.items, isNotEmpty);
      expect(
        c.payables.value.items.every(
          (p) => p.ownershipType == OwnershipType.credit,
        ),
        isTrue,
      );
    });

    test(
      'a partial payment updates paid, status and records history',
      () async {
        final p = target();
        final before = p.supplierPaidAmount ?? 0;
        final ok = await c.pay(
          product: p,
          amount: 1000,
          channel: PaymentChannel.cash,
          bankId: null,
          requestId: 'r1',
        );
        expect(ok, isTrue);
        expect(c.notice.value?.tag, 'payment');
        expect(
          c.notice.value?.message,
          contains('recorded for ${p.brandName} ${p.modelName}'),
        );
        final after = c.payables.value.items.firstWhere((x) => x.id == p.id);
        expect(after.supplierPaidAmount, before + 1000);
        expect(after.supplierPaymentStatus, SupplierPaymentStatus.partial);
        final h = await c.history(p.id);
        expect(h.single.amount, 1000);
        expect(h.single.reference, startsWith('SUP-PAY-${p.id}-'));
      },
    );

    test(
      'paying the full balance clears it and removes it from the list',
      () async {
        final p = target();
        await c.pay(
          product: p,
          amount: p.supplierOutstanding,
          channel: PaymentChannel.cash,
          bankId: null,
          requestId: 'full',
        );
        expect(c.payables.value.items.any((x) => x.id == p.id), isFalse);
      },
    );

    test(
      'overpayment is refused (React would store it) and nothing changes',
      () async {
        final p = target();
        final ok = await c.pay(
          product: p,
          amount: p.supplierOutstanding + 1,
          channel: PaymentChannel.cash,
          bankId: null,
          requestId: 'over',
        );
        expect(ok, isFalse);
        expect(c.notice.value?.isError, isTrue);
        expect(await c.history(p.id), isEmpty);
      },
    );

    test('a zero amount gets the React message', () async {
      final ok = await c.pay(
        product: target(),
        amount: 0,
        channel: PaymentChannel.cash,
        bankId: null,
        requestId: 'zero',
      );
      expect(ok, isFalse);
      expect(c.notice.value?.message, 'Enter a valid payment amount');
    });

    test('bank payments need an account and remember its name', () async {
      final p = target();
      expect(
        await c.pay(
          product: p,
          amount: 100,
          channel: PaymentChannel.bank,
          bankId: null,
          requestId: 'nb',
        ),
        isFalse,
      );
      await c.loadBanks();
      final bank = c.banks.value.items.first;
      expect(
        await c.pay(
          product: p,
          amount: 100,
          channel: PaymentChannel.bank,
          bankId: bank.id,
          requestId: 'wb',
        ),
        isTrue,
      );
      expect((await c.history(p.id)).single.bankName, bank.name);
    });

    test('the same request id never pays twice (double submit)', () async {
      final p = target();
      Future<bool> go() => c.pay(
        product: p,
        amount: 500,
        channel: PaymentChannel.cash,
        bankId: null,
        requestId: 'same',
      );
      await Future.wait([go(), go()]);
      await go(); // a late retry with the same id
      expect(await c.history(p.id), hasLength(1));
      final after = c.payables.value.items.firstWhere((x) => x.id == p.id);
      expect(after.supplierPaidAmount, (p.supplierPaidAmount ?? 0) + 500);
    });
  });

  group('Inventory Payables screen', () {
    testWidgets('lists payables, records a payment from the row menu', (
      tester,
    ) async {
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
      Get.offNamed(AppRoutes.inventoryPayables);
      await tester.pumpAndSettle();

      expect(find.text('Inventory Payables'), findsWidgets);
      expect(find.text('DUE NOW (SOLD OUT)'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);

      final c = Get.find<InventoryPayablesController>();
      final before = c.payables.value.items.length;
      await tester.tap(find.byTooltip('Actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Remaining:'), findsOneWidget);
      // Over-paying is blocked inline.
      await tester.enterText(find.byType(TextFormField).first, '99999999');
      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('exceeds the outstanding balance'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Payment of'), findsOneWidget);
      expect(c.payables.value.items.length, before); // partial: still listed
    });
  });
}
