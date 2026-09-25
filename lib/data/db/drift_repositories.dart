// ---------------------------------------------------------------------------
// The real repositories (issue #13). Same four interfaces the mock repos in
// data/mock/mock_repositories.dart already implement — screens don't know
// or care which one they're wired to (design.md, "UI-first approach").
//
// Swapped in via app_providers.dart's provider overrides; no screen in
// lib/ui or lib/widgets changes for this.
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/repositories/repositories.dart';
import 'app_database.dart';
import 'mappers.dart';

class DriftUnitRepository implements UnitRepository {
  DriftUnitRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<MoneyUnit>> watchUnits({bool includeArchived = false}) {
    final query = _db.select(_db.units)
      ..orderBy([(u) => OrderingTerm(expression: u.sortOrder)]);
    if (!includeArchived) {
      query.where((u) => u.archived.equals(false));
    }
    return query.watch().map((rows) => rows.map(unitFromRow).toList());
  }

  @override
  Future<void> addUnit(MoneyUnit unit) {
    return _db.into(_db.units).insertOnConflictUpdate(unitToCompanion(unit));
  }

  @override
  Future<void> updateUnit(MoneyUnit unit) {
    return _db.into(_db.units).insertOnConflictUpdate(unitToCompanion(unit));
  }

  @override
  Future<void> archiveUnit(String unitId) {
    return (_db.update(_db.units)..where((u) => u.id.equals(unitId))).write(
      const UnitsCompanion(archived: Value(true)),
    );
  }
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<MoneyTransaction>> watchTransactions({String? unitId}) {
    final query = _db.select(_db.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    final wantedUnitId = unitId;
    if (wantedUnitId != null) {
      query.where((t) => t.unitId.equals(wantedUnitId));
    }
    return query.watch().map((rows) => rows.map(transactionFromRow).toList());
  }

  @override
  Future<void> addTransaction(MoneyTransaction transaction) {
    return _db
        .into(_db.transactions)
        .insertOnConflictUpdate(transactionToCompanion(transaction));
  }

  @override
  Future<void> confirmTransaction(String transactionId) {
    return (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(status: Value(TxStatus.confirmed.name)),
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) {
    return (_db.delete(
      _db.transactions,
    )..where((t) => t.id.equals(transactionId))).go();
  }
}

class DriftLimitRepository implements LimitRepository {
  DriftLimitRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<LimitRule>> watchLimits() {
    return _db.select(_db.limitRules).watch().map(
          (rows) => rows.map(limitRuleFromRow).toList(),
    );
  }

  @override
  Future<void> setLimit(LimitRule limit) {
    return _db
        .into(_db.limitRules)
        .insertOnConflictUpdate(limitRuleToCompanion(limit));
  }
}

/// Settings are stored as key/value rows (design.md), so this repository
/// also owns the mapping to/from [AppSettings] — no other class needs to
/// know the on-disk shape.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);
  final AppDatabase _db;

  static const _kName = 'name';
  static const _kAccent = 'accentValue';
  static const _kThemeMode = 'themeMode';
  static const _kHomeHeadline = 'homeHeadline';
  static const _kHomeSections = 'homeSections'; // comma-separated enum names
  static const _kDetailLevel = 'detailLevel';
  static const _kAmountsHidden = 'amountsHiddenInRecents';
  static const _kRedactedBanner = 'redactedLockScreenBanner';

  @override
  Stream<AppSettings> watchSettings() {
    return _db.select(_db.settingsEntries).watch().map(_toSettings);
  }

  @override
  Future<void> updateSettings(AppSettings settings) {
    final entries = _toEntries(settings);
    // Replace the whole set in one transaction: simpler and safer than
    // diffing which keys changed, and this table is tiny (under a dozen
    // rows), so there's no performance reason not to.
    return _db.transaction(() async {
      await _db.delete(_db.settingsEntries).go();
      await _db.batch((b) => b.insertAll(_db.settingsEntries, entries));
    });
  }

  List<SettingsEntriesCompanion> _toEntries(AppSettings s) {
    return [
      SettingsEntriesCompanion.insert(key: _kName, value: s.name),
      SettingsEntriesCompanion.insert(
        key: _kAccent,
        value: s.accent.toARGB32().toString(),
      ),
      SettingsEntriesCompanion.insert(key: _kThemeMode, value: s.themeMode.name),
      SettingsEntriesCompanion.insert(
        key: _kHomeHeadline,
        value: s.homeHeadline.name,
      ),
      SettingsEntriesCompanion.insert(
        key: _kHomeSections,
        value: s.homeSections.map((e) => e.name).join(','),
      ),
      SettingsEntriesCompanion.insert(
        key: _kDetailLevel,
        value: s.detailLevel.name,
      ),
      SettingsEntriesCompanion.insert(
        key: _kAmountsHidden,
        value: s.amountsHiddenInRecents.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kRedactedBanner,
        value: s.redactedLockScreenBanner.toString(),
      ),
    ];
  }

  AppSettings _toSettings(List<SettingsEntryRow> rows) {
    // Before the first updateSettings() call the table is empty (a fresh
    // install) — fall back to AppSettings.defaults entirely rather than
    // half-constructing settings from missing keys.
    if (rows.isEmpty) return AppSettings.defaults;

    final map = {for (final r in rows) r.key: r.value};
    final defaults = AppSettings.defaults;

    T byName<T extends Enum>(String? raw, List<T> values, T fallback) {
      if (raw == null) return fallback;
      return values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    }

    bool boolOr(String? raw, bool fallback) {
      if (raw == null) return fallback;
      return raw.toLowerCase() == 'true';
    }

    return AppSettings(
      name: map[_kName] ?? defaults.name,
      accent: map[_kAccent] != null
          ? Color(int.parse(map[_kAccent]!))
          : defaults.accent,
      themeMode: byName(map[_kThemeMode], AppThemeMode.values, defaults.themeMode),
      homeHeadline: byName(
        map[_kHomeHeadline],
        HomeHeadline.values,
        defaults.homeHeadline,
      ),
      homeSections: map[_kHomeSections] != null && map[_kHomeSections]!.isNotEmpty
          ? map[_kHomeSections]!
          .split(',')
          .map(
            (n) => HomeSection.values.firstWhere(
              (v) => v.name == n,
          orElse: () => HomeSection.units,
        ),
      )
          .toSet()
          : defaults.homeSections,
      detailLevel: byName(
        map[_kDetailLevel],
        DetailLevel.values,
        defaults.detailLevel,
      ),
      amountsHiddenInRecents: boolOr(
        map[_kAmountsHidden],
        defaults.amountsHiddenInRecents,
      ),
      redactedLockScreenBanner: boolOr(
        map[_kRedactedBanner],
        defaults.redactedLockScreenBanner,
      ),
    );
  }
}
