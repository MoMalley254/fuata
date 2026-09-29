// Round-trip tests for the drift schema and repositories: every value
// that goes in through a repository's write method should come back out
// unchanged through its stream, including enums, nullable fields and
// signed amounts. Run against an in-memory database, never a real file.
//
// Needs code generation first: dart run build_runner build

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('unit round-trips through DriftUnitRepository', () async {
    final repo = DriftUnitRepository(db);
    final unit = MoneyUnit(
      id: 'u1',
      name: 'Cash',
      kind: UnitKind.cash,
      currencyCode: 'KES',
      iconEmoji: '💵',
      color: const Color(0xFF2E9E6B),
      openingBalanceMinor: 76000,
      sortOrder: 0,
      createdAt: DateTime(2026, 9, 21, 8, 0),
    );

    await repo.addUnit(unit);
    final units = await repo.watchUnits().first;

    expect(units, hasLength(1));
    expect(units.single.name, 'Cash');
    expect(units.single.kind, UnitKind.cash);
    expect(units.single.openingBalanceMinor, 76000);
    expect(units.single.color.toARGB32(), const Color(0xFF2E9E6B).toARGB32());

    await repo.archiveUnit('u1');
    expect(await repo.watchUnits().first, isEmpty);
    expect(await repo.watchUnits(includeArchived: true).first, hasLength(1));
  });

  test('transaction round-trips, including a moved pair', () async {
    final units = DriftUnitRepository(db);
    final txs = DriftTransactionRepository(db);

    for (final id in ['u_cash', 'u_bank']) {
      await units.addUnit(
        MoneyUnit(
          id: id,
          name: id,
          kind: UnitKind.cash,
          currencyCode: 'KES',
          iconEmoji: '💵',
          color: const Color(0xFF000000),
          openingBalanceMinor: 0,
          sortOrder: 0,
          createdAt: DateTime(2026, 9, 21),
        ),
      );
    }

    await txs.addTransaction(
      MoneyTransaction(
        id: 't_out',
        unitId: 'u_bank',
        type: TxType.moved,
        amountMinor: -20000,
        occurredAt: DateTime(2026, 9, 21, 12),
        createdAt: DateTime(2026, 9, 21, 12),
        transferGroupId: 'g1',
      ),
    );
    await txs.addTransaction(
      MoneyTransaction(
        id: 't_in',
        unitId: 'u_cash',
        type: TxType.moved,
        amountMinor: 20000,
        occurredAt: DateTime(2026, 9, 21, 12),
        createdAt: DateTime(2026, 9, 21, 12),
        transferGroupId: 'g1',
      ),
    );

    final all = await txs.watchTransactions().first;
    expect(all, hasLength(2));
    expect(all.every((t) => t.transferGroupId == 'g1'), isTrue);

    final cashOnly = await txs.watchTransactions(unitId: 'u_cash').first;
    expect(cashOnly, hasLength(1));
    expect(cashOnly.single.id, 't_in');

    await txs.deleteTransaction('t_out');
    expect(await txs.watchTransactions().first, hasLength(1));
  });

  test('updateTransaction edits a row in place by id', () async {
    final units = DriftUnitRepository(db);
    final txs = DriftTransactionRepository(db);
    await units.addUnit(
      MoneyUnit(
        id: 'u1',
        name: 'Cash',
        kind: UnitKind.cash,
        currencyCode: 'KES',
        iconEmoji: '💵',
        color: const Color(0xFF000000),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 21),
      ),
    );
    await txs.addTransaction(
      MoneyTransaction(
        id: 't1',
        unitId: 'u1',
        type: TxType.spent,
        amountMinor: -35000,
        counterparty: 'JAVA HSE',
        occurredAt: DateTime(2026, 9, 27, 13, 12),
        createdAt: DateTime(2026, 9, 27, 13, 12),
        status: TxStatus.pending,
        source: TxSource.shared,
      ),
    );

    // The review inbox's Fix (#21): same id, new fields, still pending.
    await txs.updateTransaction(
      MoneyTransaction(
        id: 't1',
        unitId: 'u1',
        type: TxType.spent,
        amountMinor: -3500,
        counterparty: 'Java House',
        occurredAt: DateTime(2026, 9, 27, 13, 12),
        createdAt: DateTime(2026, 9, 27, 13, 12),
        status: TxStatus.pending,
        source: TxSource.shared,
      ),
    );

    final all = await txs.watchTransactions().first;
    expect(all, hasLength(1)); // upsert, not a second row
    expect(all.single.amountMinor, -3500);
    expect(all.single.counterparty, 'Java House');
    expect(all.single.status, TxStatus.pending);
  });

  test('limit round-trips and setLimit upserts by id', () async {
    final repo = DriftLimitRepository(db);
    final daily = LimitRule(
      id: 'l_daily',
      scope: LimitScope.overall,
      period: LimitPeriod.day,
      amountMinor: 200000,
      currencyCode: 'KES',
    );

    await repo.setLimit(daily);
    await repo.setLimit(daily); // same id: should update, not duplicate

    final limits = await repo.watchLimits().first;
    expect(limits, hasLength(1));
    expect(limits.single.amountMinor, 200000);
    expect(limits.single.statusFor(100000), SpendStatus.safe);      // ratio 0.50
    expect(limits.single.statusFor(200000), SpendStatus.overdraft); // ratio 1.00
  });

  test('settings fall back to defaults, then round-trip after a save', () async {
    final repo = DriftSettingsRepository(db);

    expect((await repo.watchSettings().first).name, AppSettings.defaults.name);
    expect((await repo.watchSettings().first).autoAcceptCaptures, isFalse);

    final updated = AppSettings.defaults.copyWith(
      name: 'Amina',
      detailLevel: DetailLevel.detailed,
      homeSections: {HomeSection.lately},
      autoAcceptCaptures: true,
    );
    await repo.updateSettings(updated);

    final saved = await repo.watchSettings().first;
    expect(saved.name, 'Amina');
    expect(saved.detailLevel, DetailLevel.detailed);
    expect(saved.homeSections, {HomeSection.lately});
    expect(saved.autoAcceptCaptures, isTrue);
  });

  test('unparsed captures round-trip and purge after 7 days', () async {
    final repo = DriftCaptureRepository(db);

    // Seed an old row directly, as if recorded a week ago.
    await db.into(db.unparsedCaptures).insert(
      UnparsedCapturesCompanion.insert(
        id: 'old',
        receivedAt:
        DateTime.now().toUtc().subtract(const Duration(days: 8)),
        sourcePackage: 'shared',
        rawText: 'an old unreadable message',
      ),
    );

    await repo.recordUnparsed(
      id: 'new',
      sourcePackage: 'shared',
      rawText: 'Confirmed. Ksh350.00 paid to JAVA HOUSE...',
    );

    final rows = await repo.watchUnparsed().first;
    expect(rows, hasLength(1)); // the old one was purged on the way in
    expect(rows.single.id, 'new');
    expect(rows.single.rawText, contains('JAVA HOUSE'));

    await repo.deleteUnparsed('new');
    expect(await repo.watchUnparsed().first, isEmpty);
  });
}