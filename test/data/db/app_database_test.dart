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
import 'package:fuata/domain/logic/alert_service.dart';
import 'package:fuata/domain/models/limit_alert.dart';
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

  test('unit archive and unarchive round-trip (#80)', () async {
    final repo = DriftUnitRepository(db);
    await repo.addUnit(
      MoneyUnit(
        id: 'u1',
        name: 'Cash',
        kind: UnitKind.cash,
        currencyCode: 'KES',
        iconEmoji: '💵',
        color: const Color(0xFF2E9E6B),
        openingBalanceMinor: 0,
        sortOrder: 7,   // deliberately not 0, so a stray reset would show
        createdAt: DateTime(2026, 9, 21),
      ),
    );

    await repo.archiveUnit('u1');
    final archived = (await repo.watchUnits(includeArchived: true).first).single;
    expect(archived.archived, isTrue);
    expect(archived.archivedAt, isNotNull);

    await repo.unarchiveUnit('u1');
    final restored = (await repo.watchUnits().first).single;
    expect(restored.archived, isFalse);
    expect(restored.archivedAt, isNull);
    // Sort position survives the round trip: the whole point of clearing
    // only `archived` and `archivedAt`.
    expect(restored.sortOrder, 7);
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

  test('app lock settings persist (#28)', () async {
    final repo = DriftSettingsRepository(db);

    // An install that predates #28 has no key: the default is off.
    expect((await repo.watchSettings().first).appLockEnabled, isFalse);
    expect((await repo.watchSettings().first).appLockBiometric, isFalse);

    await repo.updateSettings(
      AppSettings.defaults.copyWith(
        appLockEnabled: true,
        appLockBiometric: true,
      ),
    );

    final saved = await repo.watchSettings().first;
    expect(saved.appLockEnabled, isTrue);
    expect(saved.appLockBiometric, isTrue);

    // Turning the lock off leaves the biometric preference intact, so
    // turning it back on keeps the person's choice instead of silently
    // resetting it.
    await repo.updateSettings(saved.copyWith(appLockEnabled: false));
    final off = await repo.watchSettings().first;
    expect(off.appLockEnabled, isFalse);
    expect(off.appLockBiometric, isTrue);
  });

  group('limit alerts (#63)', () {
    const key = AlertKey('l_overall_day', '2026-09-30', AlertLevel.warning);
    final at = DateTime(2026, 9, 30, 12);

    test('a key can be claimed exactly once', () async {
      final log = DriftAlertLogRepository(db);
      expect(await log.claim(key, at), isTrue);
      expect(await log.claim(key, at), isFalse);
      expect(await log.firedKeys(), {key});
    });

    test('purgeBefore drops old rows and keeps recent ones', () async {
      final log = DriftAlertLogRepository(db);
      await log.claim(key, DateTime(2026, 6, 1));
      await log.claim(
        const AlertKey('l_overall_day', '2026-09-30', AlertLevel.danger),
        at,
      );
      await log.purgeBefore(DateTime(2026, 7, 1));
      final left = await log.firedKeys();
      expect(left.map((k) => k.level), [AlertLevel.danger]);
    });

    LimitRule dayLimit({int amount = 100000, double warn = 0.7}) => LimitRule(
      id: 'l_overall_day',
      scope: LimitScope.overall,
      period: LimitPeriod.day,
      amountMinor: amount,
      currencyCode: 'KES',
      warnAt: warn,
    );

    test('changing a limit\'s amount clears what was already announced',
            () async {
          final limits = DriftLimitRepository(db);
          final log = DriftAlertLogRepository(db);
          await limits.setLimit(dayLimit());
          await log.claim(key, at);

          await limits.setLimit(dayLimit(amount: 500000));
          expect(await log.firedKeys(), isEmpty);
        });

    test('editing only the alert levels keeps what was announced', () async {
      final limits = DriftLimitRepository(db);
      final log = DriftAlertLogRepository(db);
      await limits.setLimit(dayLimit());
      await log.claim(key, at);

      await limits.setLimit(dayLimit(warn: 0.6));
      expect(await log.firedKeys(), {key});
    });

    test('deleting a limit clears its announcements', () async {
      final limits = DriftLimitRepository(db);
      final log = DriftAlertLogRepository(db);
      await limits.setLimit(dayLimit());
      await log.claim(key, at);

      await limits.deleteLimit('l_overall_day');
      expect(await log.firedKeys(), isEmpty);
    });

    test('claimDueAlerts announces a crossing once, then stays quiet',
            () async {
          final units = DriftUnitRepository(db);
          final txs = DriftTransactionRepository(db);
          final limits = DriftLimitRepository(db);
          final settings = DriftSettingsRepository(db);
          final log = DriftAlertLogRepository(db);

          await units.addUnit(MoneyUnit(
            id: 'u1',
            name: 'Cash',
            kind: UnitKind.cash,
            currencyCode: 'KES',
            iconEmoji: '💵',
            color: const Color(0xFF000000),
            openingBalanceMinor: 0,
            sortOrder: 0,
            createdAt: DateTime(2026, 9, 1),
          ));
          await limits.setLimit(dayLimit());
          await txs.addTransaction(MoneyTransaction(
            id: 't1',
            unitId: 'u1',
            type: TxType.spent,
            amountMinor: -75000,
            occurredAt: at,
            createdAt: at,
          ));

          Future<AlertBatch> run() => claimDueAlerts(
            units: units,
            transactions: txs,
            limits: limits,
            settings: settings,
            log: log,
            now: () => at,
          );

          final first = await run();
          expect(first.alerts, hasLength(1));
          expect(first.alerts.single.level, AlertLevel.warning);
          expect(first.quiet, isFalse);

          // Same data, evaluated again (the other isolate, or a re-run):
          // nothing more to say.
          expect((await run()).alerts, isEmpty);
        });

    test('alerts off means nothing is claimed', () async {
      final units = DriftUnitRepository(db);
      final txs = DriftTransactionRepository(db);
      final limits = DriftLimitRepository(db);
      final settings = DriftSettingsRepository(db);
      final log = DriftAlertLogRepository(db);

      await settings.updateSettings(
        AppSettings.defaults.copyWith(alertsEnabled: false),
      );
      await units.addUnit(MoneyUnit(
        id: 'u1',
        name: 'Cash',
        kind: UnitKind.cash,
        currencyCode: 'KES',
        iconEmoji: '💵',
        color: const Color(0xFF000000),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 1),
      ));
      await limits.setLimit(dayLimit());
      await txs.addTransaction(MoneyTransaction(
        id: 't1',
        unitId: 'u1',
        type: TxType.spent,
        amountMinor: -95000,
        occurredAt: at,
        createdAt: at,
      ));

      final batch = await claimDueAlerts(
        units: units,
        transactions: txs,
        limits: limits,
        settings: settings,
        log: log,
        now: () => at,
      );
      expect(batch.alerts, isEmpty);
      // And it must not have quietly used the alert up.
      expect(await log.firedKeys(), isEmpty);
    });

    test('quiet hours and the new settings round-trip', () async {
      final settings = DriftSettingsRepository(db);
      await settings.updateSettings(
        AppSettings.defaults.copyWith(
          alertsEnabled: false,
          quietHoursEnabled: true,
          quietStartMinute: 21 * 60 + 30,
          quietEndMinute: 6 * 60,
        ),
      );
      final saved = await settings.watchSettings().first;
      expect(saved.alertsEnabled, isFalse);
      expect(saved.quietHoursEnabled, isTrue);
      expect(saved.quietStartMinute, 21 * 60 + 30);
      expect(saved.quietEndMinute, 6 * 60);
    });

    test('a quiet-hours alert is flagged quiet', () async {
      final units = DriftUnitRepository(db);
      final txs = DriftTransactionRepository(db);
      final limits = DriftLimitRepository(db);
      final settings = DriftSettingsRepository(db);
      final log = DriftAlertLogRepository(db);
      final lateNight = DateTime(2026, 9, 30, 23, 15);

      await settings.updateSettings(
        AppSettings.defaults.copyWith(quietHoursEnabled: true),
      );
      await units.addUnit(MoneyUnit(
        id: 'u1',
        name: 'Cash',
        kind: UnitKind.cash,
        currencyCode: 'KES',
        iconEmoji: '💵',
        color: const Color(0xFF000000),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 1),
      ));
      await limits.setLimit(dayLimit());
      await txs.addTransaction(MoneyTransaction(
        id: 't1',
        unitId: 'u1',
        type: TxType.spent,
        amountMinor: -95000,
        occurredAt: lateNight,
        createdAt: lateNight,
      ));

      final batch = await claimDueAlerts(
        units: units,
        transactions: txs,
        limits: limits,
        settings: settings,
        log: log,
        now: () => lateNight,
      );
      expect(batch.alerts, hasLength(1));
      expect(batch.quiet, isTrue);
    });
  });
  test('unparsed captures round-trip and purge after 14 days', () async {
    final repo = DriftCaptureRepository(db);

    await db.into(db.unparsedCaptures).insert(
      UnparsedCapturesCompanion.insert(
        id: 'old',
        receivedAt:
        DateTime.now().toUtc().subtract(const Duration(days: 15)),
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

    await repo.deleteUnparsed('new');
    expect(await repo.watchUnparsed().first, isEmpty);
  });

  test('unparsed captures are capped at the newest 200', () async {
    final repo = DriftCaptureRepository(db);

    // Seed 199 "existing" rows directly, oldest first, all inside the
    // retention window so only the cap can touch them.
    final now = DateTime.now().toUtc();
    for (var i = 0; i < 199; i++) {
      await db.into(db.unparsedCaptures).insert(
        UnparsedCapturesCompanion.insert(
          id: 'seed_$i',
          receivedAt: now.subtract(Duration(minutes: 199 - i)),
          sourcePackage: 'shared',
          rawText: 'seeded $i',
        ),
      );
    }

    // Two more through the repository: 201 total, so one oldest falls off.
    await repo.recordUnparsed(
        id: 'a', sourcePackage: 'shared', rawText: 'a');
    await repo.recordUnparsed(
        id: 'b', sourcePackage: 'shared', rawText: 'b');

    final rows = await repo.watchUnparsed().first;
    expect(rows, hasLength(200));
    expect(rows.any((r) => r.id == 'seed_0'), isFalse);  // oldest gone
    expect(rows.any((r) => r.id == 'b'), isTrue);        // newest kept
  });
}
