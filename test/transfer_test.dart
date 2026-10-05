import 'package:bullion_erp/core/error/failures.dart';
import 'package:bullion_erp/features/accounts/inventory/data/datasources/mock_inventory_datasource.dart';
import 'package:bullion_erp/features/accounts/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:bullion_erp/features/accounts/inventory/data/repositories/transfer_repository_impl.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/inventory_records.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/entities/product_transfer.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/repositories/inventory_repository.dart';
import 'package:bullion_erp/features/accounts/inventory/domain/repositories/transfer_repository.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/bindings/inventory_binding.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/controllers/product_transfer_controller.dart';
import 'package:bullion_erp/features/accounts/inventory/presentation/pages/product_transfer_page.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/harness.dart';

/// Unwraps a `Right`, failing the test with the failure message otherwise.
T _ok<T>(Either<Failure, T> e) => e.fold(
  (f) => throw TestFailure('unexpected failure: ${f.message}'),
  (v) => v,
);

/// Unwraps a `Left`, failing the test if the call unexpectedly succeeded.
Failure _bad<T>(Either<Failure, T> e) =>
    e.fold((f) => f, (_) => throw TestFailure('expected a failure'));

/// Product transfer workflow (owner decision 4), through the real repository
/// implementations (`Either<Failure, T>`) over the in-memory data source.
void main() {
  late TransferRepository repo;
  late InventoryRepository inventory;
  late Product product;
  late String from;
  const to = 'Riyadh Store';

  Future<Product> fresh(String id) async =>
      _ok(await inventory.fetchProducts(InventoryType.inStock))
          .firstWhere((p) => p.id == id);

  setUp(() async {
    final ds = MockInventoryDataSource(latency: Duration.zero);
    repo = TransferRepositoryImpl(ds);
    inventory = InventoryRepositoryImpl(ds);
    final all = _ok(await inventory.fetchProducts(InventoryType.inStock));
    product = all.firstWhere(
      (p) =>
          p.stock >= 3 &&
          p.receivableStatus != ReceivableStatus.pending &&
          (p.location ?? '').isNotEmpty,
    );
    from = product.location!;
  });

  TransferRequest request({
    List<String>? serials,
    String id = 'req-1',
    double cost = 90,
  }) => TransferRequest(
    date: DateTime(2026, 1, 5, 10, 30),
    transferredBy: 'Sara',
    from: from,
    to: to == from ? 'Dubai Warehouse' : to,
    lines: [
      TransferLine(
        productId: product.id,
        serials: serials ?? product.serialNumbers.take(2).toList(),
        unitValue: product.costPrice ?? 0,
      ),
    ],
    shipmentCost: cost,
    requestId: id,
  );

  Future<ProductTransfer> create({String id = 'req-1'}) async =>
      _ok(await repo.createTransfers(request(id: id))).single;

  test('create makes a Pending transfer and reserves the serials', () async {
    final t = await create();
    expect(t.status, TransferStatus.pending);
    expect(t.quantity, 2);
    expect(_ok(await repo.fetchReservedSerials()), hasLength(2));
    // Pending does not touch stock yet.
    expect((await fresh(product.id)).stock, product.stock);
  });

  test('a repeated request id never creates a duplicate', () async {
    await create(id: 'same');
    await create(id: 'same');
    expect(_ok(await repo.fetchTransfers()), hasLength(1));
  });

  test('a reserved serial cannot be transferred twice', () async {
    await create(id: 'a');
    expect(
      _bad(await repo.createTransfers(request(id: 'b'))),
      isA<ValidationFailure>(),
    );
  });

  test('dispatch -> serials In Transit and stock drops', () async {
    final t = await create();
    _ok(await repo.dispatchTransfer(t.id));
    final p = await fresh(product.id);
    for (final s in t.serials) {
      expect(p.serialStatus[s], SerialStatus.inTransit);
    }
    expect(p.stock, product.stock - 2);
  });

  test('receive moves serials, keeps stock-in dates, restores stock', () async {
    final t = await create();
    _ok(await repo.dispatchTransfer(t.id));
    _ok(await repo.receiveTransfer(t.id, receivedBy: 'Omar'));
    final p = await fresh(product.id);
    for (final s in t.serials) {
      expect(p.serialCities[s], t.to);
      expect(p.serialStatus[s], SerialStatus.available);
      expect(p.serialStockInDates[s], product.serialStockInDates[s]);
    }
    expect(p.stock, product.stock);
    final saved = _ok(await repo.fetchTransfers()).single;
    expect(saved.status, TransferStatus.received);
    expect(saved.receivedBy, 'Omar');
  });

  test('receive needs a receiver and a dispatched transfer', () async {
    final t = await create();
    // Still Pending.
    expect(
      _bad(await repo.receiveTransfer(t.id, receivedBy: 'Omar')),
      isA<ValidationFailure>(),
    );
    _ok(await repo.dispatchTransfer(t.id));
    expect(
      _bad(await repo.receiveTransfer(t.id, receivedBy: ' ')),
      isA<ValidationFailure>(),
    );
  });

  test(
    'cancel releases serials from In Transit; Received cannot cancel',
    () async {
      final t = await create();
      _ok(await repo.dispatchTransfer(t.id));
      _ok(await repo.cancelTransfer(t.id));
      final p = await fresh(product.id);
      expect(p.stock, product.stock);
      expect(
        _ok(await repo.fetchTransfers()).single.status,
        TransferStatus.cancelled,
      );
      expect(_ok(await repo.fetchReservedSerials()), isEmpty);

      final t2 = await create(id: 'again');
      _ok(await repo.dispatchTransfer(t2.id));
      _ok(await repo.receiveTransfer(t2.id, receivedBy: 'Omar'));
      expect(_bad(await repo.cancelTransfer(t2.id)), isA<ValidationFailure>());
    },
  );

  test('deleting a Received transfer reverts serial locations', () async {
    final t = await create();
    _ok(await repo.dispatchTransfer(t.id));
    _ok(await repo.receiveTransfer(t.id, receivedBy: 'Omar'));
    _ok(await repo.deleteTransfer(t.id));
    final p = await fresh(product.id);
    for (final s in t.serials) {
      expect(p.serialCities[s], from);
    }
    expect(_ok(await repo.fetchTransfers()), isEmpty);
  });

  test('deleting an In Transit transfer makes the serials Available', () async {
    final t = await create();
    _ok(await repo.dispatchTransfer(t.id));
    _ok(await repo.deleteTransfer(t.id));
    expect((await fresh(product.id)).stock, product.stock);
  });

  test('receive is blocked when a serial is no longer In Transit', () async {
    final t = await create();
    _ok(await repo.dispatchTransfer(t.id));
    // A serial leaves transit (e.g. damaged) before the receive.
    _ok(
      await inventory.returnSerial(
        productId: product.id,
        serial: t.serials.first,
        damaged: true,
        by: DeletedBy.unknown,
      ),
    );
    expect(
      _bad(await repo.receiveTransfer(t.id, receivedBy: 'Omar')),
      isA<ValidationFailure>(),
    );
  });

  test('an unknown transfer is a failure, never an exception', () async {
    expect(_bad(await repo.dispatchTransfer('nope')), isA<ValidationFailure>());
  });

  test('freight shares of one submit add up to the total', () async {
    final other = _ok(await inventory.fetchProducts(InventoryType.inStock))
        .firstWhere(
          (p) =>
              p.id != product.id &&
              p.stock >= 1 &&
              p.location == from &&
              p.receivableStatus != ReceivableStatus.pending,
          orElse: () => product,
        );
    if (other.id == product.id) return; // no second product at this location
    final made = _ok(
      await repo.createTransfers(
        TransferRequest(
          date: DateTime(2026, 1, 5),
          transferredBy: 'Sara',
          from: from,
          to: 'Dubai Warehouse' == from ? to : 'Dubai Warehouse',
          lines: [
            TransferLine(
              productId: product.id,
              serials: product.serialNumbers.take(2).toList(),
              unitValue: product.costPrice ?? 1,
            ),
            TransferLine(
              productId: other.id,
              serials: other.serialNumbers.take(1).toList(),
              unitValue: other.costPrice ?? 1,
            ),
          ],
          shipmentCost: 100,
          requestId: 'multi',
        ),
      ),
    );
    final sum = made.fold<double>(0, (s, t) => s + t.shipmentCost);
    expect(sum, closeTo(100, 1e-9));
  });

  group('transfer controller', () {
    late ProductTransferController c;

    setUp(() async {
      final h = Harness.install();
      InventoryBinding().dependencies();
      final all = await h.inventory.fetchProducts(InventoryType.inStock);
      final p = all.firstWhere(
        (p) =>
            p.stock >= 2 &&
            p.receivableStatus != ReceivableStatus.pending &&
            (p.location ?? '').isNotEmpty,
      );
      c = Get.find<ProductTransferController>();
      await c.createTransfers(
        TransferRequest(
          date: DateTime(2026, 1, 5, 9, 5),
          transferredBy: 'Sara',
          from: p.location!,
          to: 'Elsewhere',
          lines: [
            TransferLine(
              productId: p.id,
              serials: p.serialNumbers.take(2).toList(),
            ),
          ],
          requestId: 'c-1',
        ),
      );
    });

    test('create reports success and lists the transfer', () {
      expect(c.notice.value?.tag, 'create');
      expect(c.transfers.value.items.single.status, TransferStatus.pending);
      expect(c.reserved, hasLength(2));
    });

    test('dispatch then receive, with messages', () async {
      final id = c.transfers.value.items.single.id;
      await c.dispatch(id);
      expect(c.notice.value?.message, 'Transfer dispatched — now In Transit');
      await c.receive(id, 'Omar');
      expect(c.transfers.value.items.single.status, TransferStatus.received);
      expect(c.reserved, isEmpty);
    });

    test('a failed command is reported as an error notice', () async {
      await c.receive(c.transfers.value.items.single.id, 'Omar'); // Pending
      expect(c.notice.value?.isError, isTrue);
      expect(c.busy.value, isFalse);
    });

    test('a second tap while busy is ignored', () async {
      final id = c.transfers.value.items.single.id;
      final a = c.dispatch(id);
      final b = c.dispatch(id);
      await Future.wait([a, b]);
      expect(c.notice.value?.isError, isFalse);
    });
  });

  group('Product Transfer screen', () {
    testWidgets('Pending -> Dispatch -> Receive through the row menu', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      resetGet();
      final h = Harness.fresh();
      h.bindings.dependencies();
      InventoryBinding().dependencies();

      // Repository calls use real timers: run them outside the fake clock.
      final p =
          (await tester.runAsync(
            () => h.inventory.fetchProducts(InventoryType.inStock),
          ))!.firstWhere(
            (p) =>
                p.stock >= 2 &&
                p.receivableStatus != ReceivableStatus.pending &&
                (p.location ?? '').isNotEmpty,
          );
      await tester.runAsync(
        () => h.inventory.createTransfers(
          TransferRequest(
            date: DateTime(2026, 1, 5, 9, 5),
            transferredBy: 'Sara',
            from: p.location!,
            to: p.location == 'Riyadh Store'
                ? 'Dubai Warehouse'
                : 'Riyadh Store',
            lines: [
              TransferLine(
                productId: p.id,
                serials: p.serialNumbers.take(2).toList(),
              ),
            ],
            requestId: 'ui-1',
          ),
        ),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: ProductTransferPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('${p.brandName} ${p.modelName}'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);

      Future<void> menu(String item) async {
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(item).last);
        await tester.pumpAndSettle();
      }

      final c = Get.find<ProductTransferController>();
      await menu('Dispatch');
      await tester.tap(find.text('Dispatch').last);
      await tester.pumpAndSettle();
      expect(c.transfers.value.items.single.status, TransferStatus.inTransit);

      await menu('Receive');
      await tester.enterText(find.byType(TextFormField).last, 'Omar');
      await tester.tap(find.text('Mark received'));
      await tester.pumpAndSettle();
      final t = c.transfers.value.items.single;
      expect(t.status, TransferStatus.received);
      expect(t.receivedBy, 'Omar');
    });
  });
}
