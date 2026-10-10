// Issue #24: export and import against a real (in-memory) database — the
// round trip, "never overwrites silently", and all-or-nothing writes.
//
// Needs code generation first: dart run build_runner build

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/backup_repository.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/logic/backup_codec.dart';
import 'package:fuata/domain/logic/backup_import.dart';
import 'package:fuata/domain/logic/backup_service.dart';
import 'package:fuata/domain/models/backup_snapshot.dart';
import 'package:fuata/domain/models/limit_alert.dart';
import 'package:fuata/domain/models/settings.dart';

import '../../domain/backup_test_data.dart';

void main() {
  late AppDatabase db;
  late DriftBackupRepository repo;
  late BackupService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBackupRepository(db);
    service = BackupService(repo, clock: () => exportedAt);
  });

  tearDown(() => db.close());

  /// Fill a database the way the app would, through its own repositories.
  /// Wipes the seeded default categories first, so the fixture fully
  /// controls what readAll() sees.
  Future<void> seed(AppDatabase target) async {
    final snap = fullSnapshot();

    // A fresh AppDatabase seeds 9 default categories at create
    // (issue #83, _seedDefaultCategories). The fixture carries its own
    // set, so start from a clean table — otherwise every round-trip
    // comparison sees 9 extra rows and "recordCount" no longer matches
    // what "readAll()" returns.
    await target.delete(target.categories).go();

    for (final c in snap.categories) {
      await target.into(target.categories).insert(
        CategoriesCompanion.insert(
          id: c.id,
          name: c.name,
          emoji: c.emoji,
          colorValue: c.colorValue,
          sortOrder: Value(c.sortOrder),
          archived: Value(c.archived),
        ),
      );
    }

    final units = DriftUnitRepository(target);
    for (final u in snap.units) {
      await units.addUnit(u);
    }
    for (final s in snap.captureSources) {
      await DriftCaptureSourceRepository(target).saveSource(s);
    }
    for (final t in snap.templates) {
      await DriftTemplateRepository(target).saveTemplate(t);
    }
    final txs = DriftTransactionRepository(target);
    for (final t in snap.transactions) {
      await txs.addTransaction(t);
    }
    for (final l in snap.limits) {
      await DriftLimitRepository(target).setLimit(l);
    }
    await DriftSettingsRepository(target).updateSettings(snap.settings!);
  }

  Future<String> exportOf(AppDatabase target) async =>
      (await BackupService(DriftBackupRepository(target), clock: () => exportedAt)
          .buildExport())
          .json;

  test('a fresh phone exports an empty, valid backup', () async {
    final built = await service.buildExport();
    final decoded = BackupCodec.decode(built.json);

    expect(decoded.ok, isTrue);
    expect(decoded.snapshot!.units, isEmpty);
    expect(decoded.snapshot!.transactions, isEmpty);
  });

  test('export from one phone, import into another: identical data', () async {
    await seed(db);
    final json = await exportOf(db);

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    // A fresh AppDatabase seeds the 9 default categories at create
    // (issue #83). This test models an *empty* phone receiving the file,
    // so wipe them — otherwise the import lands alongside them and the
    // re-export has 9 rows the source didn't.
    await other.delete(other.categories).go();
    final otherService = BackupService(
      DriftBackupRepository(other),
      clock: () => exportedAt,
    );

    final preview = await otherService.preview(json);
    expect(preview.canImport, isTrue);
    expect(preview.phoneHasData, isFalse);
    expect(preview.plan!.hasConflicts, isFalse);

    final outcome = await otherService.apply(
      preview,
      policy: ConflictPolicy.keepMine,
      restoreSettings: true,
    );

    expect(outcome.added, fullSnapshot().recordCount);
    expect(outcome.settingsRestored, isTrue);
    // The strongest check: exporting the second phone gives the same file.
    expect(await exportOf(other), json);
  });

  test('importing the same file again changes nothing', () async {
    await seed(db);
    final json = await exportOf(db);

    final preview = await service.preview(json);

    expect(preview.plan!.changesNothing, isTrue);
    expect(preview.plan!.identicalCount, fullSnapshot().recordCount);
    expect(preview.plan!.hasConflicts, isFalse);
  });

  test('a file with a problem is refused and nothing is written', () async {
    final preview = await service.preview('definitely not a backup');

    expect(preview.canImport, isFalse);
    expect(preview.plan, isNull);
    await expectLater(
          () => service.apply(
        preview,
        policy: ConflictPolicy.useFile,
        restoreSettings: true,
      ),
      throwsStateError,
    );
    expect((await repo.readAll()).units, isEmpty);
  });

  test('a transaction for a unit that exists nowhere is refused', () async {
    final json = BackupCodec.encode(
      BackupSnapshot(transactions: [tx('t1', unitId: 'ghost')]),
      exportedAt: exportedAt,
    );

    final preview = await service.preview(json);

    expect(preview.canImport, isFalse);
    expect(preview.blockers.single, contains('money unit'));
  });

  group('never overwrites silently', () {
    Future<String> fileWithUnitNamed(String name) async => BackupCodec.encode(
      BackupSnapshot(units: [unit('u1', name: name)]),
      exportedAt: exportedAt,
    );

    test('the phone\'s version is kept by default', () async {
      await DriftUnitRepository(db).addUnit(unit('u1', name: 'Wallet'));

      final preview = await service.preview(await fileWithUnitNamed('Cash'));
      expect(preview.plan!.units.conflicts, hasLength(1));

      final outcome = await service.apply(
        preview,
        policy: ConflictPolicy.keepMine,
        restoreSettings: false,
      );

      expect((await repo.readAll()).units.single.name, 'Wallet');
      expect(outcome.skipped, 1);
      expect(outcome.replaced, 0);
    });

    test('the file\'s version replaces it only when asked', () async {
      await DriftUnitRepository(db).addUnit(unit('u1', name: 'Wallet'));

      final preview = await service.preview(await fileWithUnitNamed('Cash'));
      final outcome = await service.apply(
        preview,
        policy: ConflictPolicy.useFile,
        restoreSettings: false,
      );

      expect((await repo.readAll()).units.single.name, 'Cash');
      expect(outcome.replaced, 1);
    });

    test('new records are added alongside the phone\'s own', () async {
      await DriftUnitRepository(db).addUnit(unit('u1', name: 'Wallet'));
      final json = BackupCodec.encode(
        BackupSnapshot(units: [unit('u2', name: 'M-Pesa', sortOrder: 1)]),
        exportedAt: exportedAt,
      );

      final preview = await service.preview(json);
      await service.apply(
        preview,
        policy: ConflictPolicy.keepMine,
        restoreSettings: false,
      );

      expect((await repo.readAll()).units.map((u) => u.name), ['Wallet', 'M-Pesa']);
    });

    test('settings are left alone unless restoring them is chosen', () async {
      await DriftSettingsRepository(db)
          .updateSettings(AppSettings.defaults.copyWith(name: 'Mine'));
      final json = BackupCodec.encode(
        BackupSnapshot(units: [unit('u1')], settings: customSettings()),
        exportedAt: exportedAt,
      );

      final preview = await service.preview(json);
      await service.apply(
        preview,
        policy: ConflictPolicy.keepMine,
        restoreSettings: false,
      );
      expect((await repo.readAll()).settings!.name, 'Mine');

      await service.apply(
        preview,
        policy: ConflictPolicy.keepMine,
        restoreSettings: true,
      );
      expect((await repo.readAll()).settings!.name, 'Wanjiru');
    });
  });

  group('erase everything (#85, US-16)', () {
    /// Fill every table a backup carries, then give the two tables
    /// readAll() doesn't touch a row of their own — otherwise "every watch
    /// stream is empty" would be a claim about a table that was never
    /// written to.
    Future<void> seedEverything() async {
      await seed(db);
      await DriftAlertLogRepository(db).claim(
        const AlertKey('l_overall_day', '2026-09-30', AlertLevel.warning),
        DateTime.utc(2026, 9, 30),
      );
      await db.into(db.unparsedCaptures).insert(
        UnparsedCapturesCompanion.insert(
          id: 'u_unread',
          receivedAt: DateTime.utc(2026, 9, 30),
          sourcePackage: 'shared',
          rawText: 'a message nothing could read',
        ),
      );
    }

    test('leaves every table empty — the record tables readAll() covers', () async {
      await seedEverything();
      // Sanity: the seed actually filled things.
      expect((await repo.readAll()).recordCount, fullSnapshot().recordCount);

      await repo.eraseAll();

      final after = await repo.readAll();
      expect(after.units, isEmpty);
      expect(after.categories, isEmpty);
      expect(after.captureSources, isEmpty);
      expect(after.templates, isEmpty);
      expect(after.transactions, isEmpty);
      expect(after.limits, isEmpty);
    });

    test('leaves nothing behind in the tables readAll() does not carry',
            () async {
          await seedEverything();

          await repo.eraseAll();

          expect(await db.select(db.unparsedCaptures).get(), isEmpty);
          expect(await db.select(db.alertFirings).get(), isEmpty);
          expect(await db.select(db.settingsEntries).get(), isEmpty);
        });

    test('settings read as a fresh install again', () async {
      await seedEverything();
      // Prove the flag was true before the erase, so a false after means
      // the reset happened rather than the seed never setting it.
      await DriftSettingsRepository(db).updateSettings(
        AppSettings.defaults.copyWith(name: 'Wanjiru', onboardingComplete: true),
      );

      await repo.eraseAll();

      final s = await DriftSettingsRepository(db).watchSettings().first;
      expect(s.onboardingComplete, isFalse);
      expect(s.name, AppSettings.defaults.name);
      expect(s.bannerEnabled, AppSettings.defaults.bannerEnabled);
      expect(s.accent, AppSettings.defaults.accent);
    });

    test('erasing an already-empty database is a no-op, not an error',
            () async {
          await repo.eraseAll();
          final after = await repo.readAll();
          expect(after.isEmpty, isTrue);
          expect(after.settings, isNotNull); // still "the current defaults"
        });

    test('every stream a screen watches is empty afterwards', () async {
      await seedEverything();

      await repo.eraseAll();

      // What Home, Activity, My money, Limits, the rule builder and the
      // review inbox actually watch — the shape of the acceptance
      // criterion in the issue.
      expect(await DriftUnitRepository(db).watchUnits(includeArchived: true).first,
          isEmpty);
      expect(await DriftTransactionRepository(db).watchTransactions().first,
          isEmpty);
      expect(await DriftLimitRepository(db).watchLimits().first, isEmpty);
      expect(await DriftTemplateRepository(db).watchTemplates().first, isEmpty);
      expect(await DriftCaptureRepository(db).watchUnparsed().first, isEmpty);
      expect(await DriftCaptureSourceRepository(db).watchSources().first,
          isEmpty);
      expect(await DriftAlertLogRepository(db).firedKeys(), isEmpty);
      expect(
        (await DriftSettingsRepository(db).watchSettings().first)
            .onboardingComplete,
        isFalse,
      );
    });
  });

  test('a write that fails half-way leaves the database untouched', () async {
    // Bypasses the planner on purpose: this is the repository's own
    // guarantee. The unit is valid, the transaction after it points at a
    // unit that does not exist, so the foreign key rejects it — and the
    // unit written just before must not survive.
    final bad = BackupSnapshot(
      units: [unit('u1')],
      transactions: [tx('t1', unitId: 'ghost')],
    );

    await expectLater(repo.apply(bad), throwsA(anything));

    final after = await repo.readAll();
    expect(after.units, isEmpty);
    expect(after.transactions, isEmpty);
  });

  test('raising a limit on import clears the alerts shown for the old amount', () async {
    final limits = DriftLimitRepository(db);
    await DriftUnitRepository(db).addUnit(unit('u1'));
    await limits.setLimit(overallDayLimit(amount: 100000));
    final alerts = DriftAlertLogRepository(db);
    final key = AlertKey(
      overallDayLimit().id,
      '2026-09-30',
      AlertLevel.warning,
    );
    expect(await alerts.claim(key, DateTime.utc(2026, 9, 30)), isTrue);

    final json = BackupCodec.encode(
      BackupSnapshot(limits: [overallDayLimit(amount: 500000)]),
      exportedAt: exportedAt,
    );
    final preview = await service.preview(json);
    await service.apply(
      preview,
      policy: ConflictPolicy.useFile,
      restoreSettings: false,
    );

    expect(await alerts.firedKeys(), isEmpty);
  });
}