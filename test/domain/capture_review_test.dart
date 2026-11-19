// The logic behind both "Looks right" / "Not mine" in the review inbox and
// the Accept / Discard buttons on a caught-payment notification. Real
// CaptureReview against real drift repositories on an in-memory database.
// Fake data only.
//
// Needs code generation first: dart run build_runner build

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/logic/capture_review.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  late AppDatabase db;
  late DriftTransactionRepository txs;
  late CaptureReview review;

  final at = DateTime(2026, 9, 21, 13, 12);

  MoneyTransaction capture({
    String id = 'cap_1',
    int amountMinor = -35000,
    TxStatus status = TxStatus.pending,
    int? balanceAfterMinor,
    String? parentId,
  }) => MoneyTransaction(
    id: id,
    unitId: 'u_mm',
    type: TxType.spent,
    amountMinor: amountMinor,
    counterparty: 'JAVA HOUSE',
    occurredAt: at,
    createdAt: at,
    source: TxSource.notification,
    status: status,
    balanceAfterMinor: balanceAfterMinor,
    parentId: parentId,
  );

  Future<MoneyTransaction?> byId(String id) async =>
      (await txs.watchTransactions().first)
          .where((t) => t.id == id)
          .firstOrNull;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    txs = DriftTransactionRepository(db);
    final units = DriftUnitRepository(db);
    await units.addUnit(
      MoneyUnit(
        id: 'u_mm',
        name: 'Mobile money',
        kind: UnitKind.mobileMoney,
        currencyCode: 'KES',
        iconEmoji: '📱',
        color: const Color(0xFF3D7FE0),
        openingBalanceMinor: 100000, // KES 1,000.00
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    review = CaptureReview(transactions: txs, units: units);
  });

  tearDown(() => db.close());

  group('accept', () {
    test('confirms the capture and its fee row together', () async {
      await txs.addTransaction(capture());
      await txs.addTransaction(
        capture(id: 'cap_1_fee', amountMinor: -500, parentId: 'cap_1'),
      );

      final result = await review.accept('cap_1');

      expect(result.found, isTrue);
      expect((await byId('cap_1'))!.isConfirmed, isTrue);
      expect((await byId('cap_1_fee'))!.isConfirmed, isTrue);
    });

    test('a quoted balance that matches the ledger is not a mismatch', () async {
      // 1,000.00 opening - 350.00 - 5.00 fee = 645.00
      await txs.addTransaction(capture(balanceAfterMinor: 64500));
      await txs.addTransaction(
        capture(id: 'cap_1_fee', amountMinor: -500, parentId: 'cap_1'),
      );

      final result = await review.accept('cap_1');

      expect(result.ledgerBalanceMinor, 64500);
      expect(result.balanceMismatch, isFalse);
    });

    test('a quoted balance that disagrees is flagged, with both numbers', () async {
      await txs.addTransaction(capture(balanceAfterMinor: 70000));

      final result = await review.accept('cap_1');

      expect(result.balanceMismatch, isTrue);
      expect(result.quotedBalanceMinor, 70000);
      expect(result.ledgerBalanceMinor, 65000); // 1,000.00 - 350.00
      expect(result.unit!.id, 'u_mm');
    });

    test('no quoted balance means nothing to reconcile', () async {
      await txs.addTransaction(capture());

      final result = await review.accept('cap_1');

      expect(result.found, isTrue);
      expect(result.balanceMismatch, isFalse);
    });

    test('already-confirmed money is counted in the ledger figure', () async {
      await txs.addTransaction(
        capture(id: 'earlier', amountMinor: -10000, status: TxStatus.confirmed),
      );
      await txs.addTransaction(capture(balanceAfterMinor: 55000));

      final result = await review.accept('cap_1');

      // 1,000.00 - 100.00 - 350.00 = 550.00
      expect(result.ledgerBalanceMinor, 55000);
      expect(result.balanceMismatch, isFalse);
    });

    test('a second press finds nothing and changes nothing', () async {
      await txs.addTransaction(capture());
      await review.accept('cap_1');

      final again = await review.accept('cap_1');

      expect(again.found, isFalse);
      expect((await byId('cap_1'))!.isConfirmed, isTrue);
    });

    test('an unknown id is a quiet no-op', () async {
      final result = await review.accept('nope');
      expect(result.found, isFalse);
    });
  });

  group('discard', () {
    test('removes the capture and its fee row', () async {
      await txs.addTransaction(capture());
      await txs.addTransaction(
        capture(id: 'cap_1_fee', amountMinor: -500, parentId: 'cap_1'),
      );

      expect(await review.discard('cap_1'), isTrue);

      expect(await txs.watchTransactions().first, isEmpty);
    });

    test('never deletes money the person already confirmed', () async {
      // The stale-button case: accepted in the app, then Discard pressed on
      // a notification that was still in the shade.
      await txs.addTransaction(capture(status: TxStatus.confirmed));

      expect(await review.discard('cap_1'), isFalse);

      expect(await byId('cap_1'), isNotNull);
    });

    test('an unknown id is a quiet no-op', () async {
      expect(await review.discard('nope'), isFalse);
    });
  });

  group('category and note from the notification (#152)', () {
    test('setCategory writes to the same pending row and nothing else', () async {
      await txs.addTransaction(capture());

      expect(await review.setCategory('cap_1', 'cat_food'), isTrue);

      final row = (await byId('cap_1'))!;
      expect(row.categoryId, 'cat_food');
      expect(row.isConfirmed, isFalse); // still waiting for Accept
      expect(row.amountMinor, -35000);
      expect(row.counterparty, 'JAVA HOUSE');
    });

    test('setNote trims, and a blank note clears it', () async {
      await txs.addTransaction(capture());

      await review.setNote('cap_1', '  lunch with Amina  ');
      expect((await byId('cap_1'))!.note, 'lunch with Amina');

      await review.setNote('cap_1', '   ');
      expect((await byId('cap_1'))!.note, isNull);
    });

    test('a note and a category set one after the other both survive', () async {
      await txs.addTransaction(capture());

      await review.setNote('cap_1', 'team lunch');
      await review.setCategory('cap_1', 'cat_food');

      final row = (await byId('cap_1'))!;
      expect(row.note, 'team lunch');
      expect(row.categoryId, 'cat_food');
    });

    test('what was set survives Accept', () async {
      await txs.addTransaction(capture());
      await review.setNote('cap_1', 'team lunch');
      await review.setCategory('cap_1', 'cat_food');

      await review.accept('cap_1');

      final row = (await byId('cap_1'))!;
      expect(row.isConfirmed, isTrue);
      expect(row.note, 'team lunch');
      expect(row.categoryId, 'cat_food');
    });

    test('a stale button cannot touch a row already confirmed', () async {
      await txs.addTransaction(capture(status: TxStatus.confirmed));

      expect(await review.setCategory('cap_1', 'cat_food'), isFalse);
      expect(await review.setNote('cap_1', 'late'), isFalse);

      final row = (await byId('cap_1'))!;
      expect(row.categoryId, isNull);
      expect(row.note, isNull);
    });

    test('an unknown id is a quiet no-op', () async {
      expect(await review.setCategory('nope', 'cat_food'), isFalse);
      expect(await review.setNote('nope', 'x'), isFalse);
    });
  });

  group('the capture-notifications setting', () {
    test('is on by default, and an old settings table reads as on', () async {
      final repo = DriftSettingsRepository(db);
      expect(AppSettings.defaults.captureNotificationsEnabled, isTrue);
      expect((await repo.watchSettings().first).captureNotificationsEnabled,
          isTrue);
    });

    test('off survives a write and a read', () async {
      final repo = DriftSettingsRepository(db);
      await repo.updateSettings(
        AppSettings.defaults.copyWith(captureNotificationsEnabled: false),
      );
      expect((await repo.watchSettings().first).captureNotificationsEnabled,
          isFalse);

      await repo.updateSettings(
        AppSettings.defaults.copyWith(captureNotificationsEnabled: true),
      );
      expect((await repo.watchSettings().first).captureNotificationsEnabled,
          isTrue);
    });
  });
}
