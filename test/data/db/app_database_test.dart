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
    expect(limits.single.statusFor(150000), SpendStatus.safe);
    expect(limits.single.statusFor(200000), SpendStatus.overdraft);
  });

  test('settings fall back to defaults, then round-trip after a save', () async {
    final repo = DriftSettingsRepository(db);

    expect((await repo.watchSettings().first).name, AppSettings.defaults.name);

    final updated = AppSettings.defaults.copyWith(
      name: 'Amina',
      detailLevel: DetailLevel.detailed,
      homeSections: {HomeSection.lately},
    );
    await repo.updateSettings(updated);

    final saved = await repo.watchSettings().first;
    expect(saved.name, 'Amina');
    expect(saved.detailLevel, DetailLevel.detailed);
    expect(saved.homeSections, {HomeSection.lately});
  });
}
