// ---------------------------------------------------------------------------
// The real repositories (issue #13). Same interfaces the mock repos in
// data/mock/mock_repositories.dart already implement — screens don't know
// or care which one they're wired to (design.md, "UI-first approach").
//
// Swapped in via app_providers.dart's provider overrides; no screen in
// lib/ui or lib/widgets changes for this.
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../domain/models/capture_source.dart';
import '../../domain/logic/unit_order.dart';
import '../../domain/models/category.dart';
import '../../domain/models/limit_alert.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/outing.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/template.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/unparsed_capture.dart';
import '../../domain/repositories/repositories.dart';
import '../constants/captures_constants.dart';
import 'app_database.dart';
import 'mappers.dart';

const _kBannerUnitsMode = 'bannerUnitsMode';

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
      UnitsCompanion(
        archived: const Value(true),
        // UTC so the Archived screen can format it in the device zone.
        archivedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> unarchiveUnit(String unitId) {
    return (_db.update(_db.units)..where((u) => u.id.equals(unitId))).write(
      UnitsCompanion(
        archived: const Value(false),
        // Explicit null, not Value.absent(): the whole point of this write
        // is to clear the timestamp.
        archivedAt: const Value<DateTime?>(null),
      ),
    );
  }

  @override
  Future<void> reorderUnits(List<String> orderedIds) {
    if (orderedIds.isEmpty) return Future.value();
    // One transaction: the stream must never emit a half-reordered list.
    return _db.transaction(() async {
      final rows = await (_db.select(
        _db.units,
      )..where((u) => u.id.isIn(orderedIds))).get();
      final next = unitSortOrdersFor(rows.map(unitFromRow), orderedIds);
      for (final entry in next.entries) {
        await (_db.update(_db.units)..where((u) => u.id.equals(entry.key)))
            .write(UnitsCompanion(sortOrder: Value(entry.value)));
      }
    });
  }

  @override
  Future<void> updateAllCurrencies(String currencyCode) {
    return _db.update(_db.units).write(
      UnitsCompanion(currency: Value(currencyCode)),
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
  Future<void> updateTransaction(MoneyTransaction transaction) {
    // insertOnConflictUpdate by primary key — the same statement as add;
    // the name just records what the caller means (the review inbox's
    // Fix action, #21). Balances pick the change up automatically since
    // they're always derived (ADR-004).
    return _db
        .into(_db.transactions)
        .insertOnConflictUpdate(transactionToCompanion(transaction));
  }

  @override
  Future<void> confirmTransaction(String transactionId) {
    return (_db.update(_db.transactions)
      ..where((t) => t.id.equals(transactionId)))
        .write(TransactionsCompanion(status: Value(TxStatus.confirmed.name)));
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
    return _db
        .select(_db.limitRules)
        .watch()
        .map((rows) => rows.map(limitRuleFromRow).toList());
  }

  @override
  Future<void> setLimit(LimitRule limit) {
    return _db.transaction(() async {
      // A different amount is a different limit: the alerts already shown
      // for the old number no longer mean anything (raise 1,000 to 5,000
      // and the person should be nudged again as they approach 5,000).
      // Editing only the alert levels or the on/off switch keeps them, so
      // dragging a slider never repeats an alert the person already saw.
      final existing = await (_db.select(
        _db.limitRules,
      )..where((l) => l.id.equals(limit.id))).getSingleOrNull();
      if (existing != null && existing.amountMinor != limit.amountMinor) {
        await _clearAlerts(limit.id);
      }
      await _db
          .into(_db.limitRules)
          .insertOnConflictUpdate(limitRuleToCompanion(limit));
    });
  }

  @override
  Future<void> deleteLimit(String limitId) {
    return _db.transaction(() async {
      await _clearAlerts(limitId);
      await (_db.delete(
        _db.limitRules,
      )..where((l) => l.id.equals(limitId))).go();
    });
  }

  Future<void> _clearAlerts(String limitId) => (_db.delete(
    _db.alertFirings,
  )..where((f) => f.limitId.equals(limitId))).go();
}

class DriftAlertLogRepository implements AlertLogRepository {
  DriftAlertLogRepository(this._db);
  final AppDatabase _db;

  @override
  Future<Set<AlertKey>> firedKeys() async {
    final rows = await _db.select(_db.alertFirings).get();
    return {
      for (final r in rows)
        AlertKey(
          r.limitId,
          r.periodKey,
          AlertLevel.values.firstWhere(
                (l) => l.name == r.level,
            orElse: () => AlertLevel.warning,
          ),
        ),
    };
  }

  @override
  Future<bool> claim(AlertKey key, DateTime at) async {
    try {
      // Plain insert, not insert-or-replace: the primary key rejects a
      // second claim, which is exactly the guarantee wanted. A racing
      // isolate that loses gets an exception here, and "could not record
      // it" is treated as "do not show it" — a missed nudge is better
      // than one that repeats forever because it can't be remembered.
      await _db
          .into(_db.alertFirings)
          .insert(
        AlertFiringsCompanion.insert(
          limitId: key.limitId,
          periodKey: key.periodKey,
          level: key.level.name,
          firedAt: at,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> purgeBefore(DateTime cutoff) => (_db.delete(
    _db.alertFirings,
  )..where((f) => f.firedAt.isSmallerThanValue(cutoff))).go();
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
  static const _kAutoAccept = 'autoAcceptCaptures';

  static const _kBannerEnabled = 'bannerEnabled';
  static const _kBannerHeadline = 'bannerHeadline';
  static const _kBannerUnitIds = 'bannerUnitIds'; // comma-separated ids
  static const _kBannerProgress = 'bannerShowProgress';
  static const _kBannerQuickAdd = 'bannerShowQuickAdd';

  static const _kSummaryEnabled = 'summaryNotificationsEnabled';
  static const _kSummaryDailyEnabled = 'summaryDailyEnabled';
  static const _kSummaryDailyMinute = 'summaryDailyMinute';
  static const _kSummaryWeeklyEnabled = 'summaryWeeklyEnabled';
  static const _kSummaryWeeklyWeekday = 'summaryWeeklyWeekday';
  static const _kSummaryWeeklyMinute = 'summaryWeeklyMinute';
  static const _kSummaryMonthlyEnabled = 'summaryMonthlyEnabled';
  static const _kSummaryMonthlyDay = 'summaryMonthlyDay';
  static const _kSummaryMonthlyMinute = 'summaryMonthlyMinute';

  static const _kAlertsEnabled = 'alertsEnabled';
  static const _kQuietEnabled = 'quietHoursEnabled';
  static const _kQuietStart = 'quietStartMinute';
  static const _kQuietEnd = 'quietEndMinute';

  static const _kOnboardingComplete = 'onboardingComplete';

  static const _kHideAmounts = 'amountsHidden'; // issue #81

  // Issue #28: the app-lock preference. Deliberately not in the backup
  // codec — a lock is a choice about *this* phone, not about the data.
  static const _kAppLockEnabled = 'appLockEnabled';
  static const _kAppLockBiometric = 'appLockBiometric';

  // Issue #113: the home-screen widget's own options. Same vocabulary
  // as the banner's, deliberately separate values — the two have
  // independent lives.
  static const _kWidgetUnitsMode = 'widgetUnitsMode';
  static const _kWidgetUnitIds = 'widgetUnitIds';
  static const _kWidgetHeadline = 'widgetHeadline';
  static const _kWidgetProgress = 'widgetShowProgress';
  static const _kWidgetSplit = 'widgetShowSplit';
  static const _kWidgetVariant = 'widgetVariant';

  static const _kCurrencyCode = 'currencyCode';

  static const _kScheduledExportEnabled = 'scheduledExportEnabled';
  static const _kScheduledExportFrequency = 'scheduledExportFrequency';
  static const _kScheduledExportMinute = 'scheduledExportMinute';
  static const _kScheduledExportWeekday = 'scheduledExportWeekday';
  static const _kScheduledExportFolderUri = 'scheduledExportFolderUri';
  static const _kScheduledExportPassphraseSet = 'scheduledExportPassphraseSet';
  static const _kScheduledExportIncludeRawText = 'scheduledExportIncludeRawText';

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
      SettingsEntriesCompanion.insert(
        key: _kThemeMode,
        value: s.themeMode.name,
      ),
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
      SettingsEntriesCompanion.insert(
        key: _kAutoAccept,
        value: s.autoAcceptCaptures.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kBannerEnabled,
        value: s.bannerEnabled.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kBannerHeadline,
        value: s.bannerHeadline.name,
      ),
      SettingsEntriesCompanion.insert(
        key: _kBannerUnitIds,
        value: s.bannerUnitIds.join(','),
      ),
      SettingsEntriesCompanion.insert(
          key: _kBannerUnitsMode, value: s.bannerUnitsMode.name),
      SettingsEntriesCompanion.insert(
        key: _kBannerProgress,
        value: s.bannerShowProgress.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kBannerQuickAdd,
        value: s.bannerShowQuickAdd.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kAlertsEnabled,
        value: s.alertsEnabled.toString(),
      ),
      SettingsEntriesCompanion.insert(key: _kSummaryEnabled, value: s.summaryNotificationsEnabled.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryDailyEnabled, value: s.summaryDailyEnabled.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryDailyMinute, value: s.summaryDailyMinute.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryWeeklyEnabled, value: s.summaryWeeklyEnabled.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryWeeklyWeekday, value: s.summaryWeeklyWeekday.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryWeeklyMinute, value: s.summaryWeeklyMinute.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryMonthlyEnabled, value: s.summaryMonthlyEnabled.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryMonthlyDay, value: s.summaryMonthlyDay.toString()),
      SettingsEntriesCompanion.insert(key: _kSummaryMonthlyMinute, value: s.summaryMonthlyMinute.toString()),
      SettingsEntriesCompanion.insert(
        key: _kQuietEnabled,
        value: s.quietHoursEnabled.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kQuietStart,
        value: s.quietStartMinute.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kQuietEnd,
        value: s.quietEndMinute.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kOnboardingComplete,
        value: s.onboardingComplete.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kHideAmounts,
        value: s.amountsHidden.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kAppLockEnabled,
        value: s.appLockEnabled.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kAppLockBiometric,
        value: s.appLockBiometric.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kWidgetUnitsMode,
        value: s.widgetUnitsMode.name,
      ),
      SettingsEntriesCompanion.insert(
        key: _kWidgetUnitIds,
        value: s.widgetUnitIds.join(','),
      ),
      SettingsEntriesCompanion.insert(
        key: _kWidgetHeadline,
        value: s.widgetHeadline.name,
      ),
      SettingsEntriesCompanion.insert(
        key: _kWidgetProgress,
        value: s.widgetShowProgress.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kWidgetSplit,
        value: s.widgetShowSplit.toString(),
      ),
      SettingsEntriesCompanion.insert(
        key: _kWidgetVariant,
        value: s.widgetVariant.name,
      ),
      SettingsEntriesCompanion.insert(
        key: _kCurrencyCode,
        value: s.currencyCode,
      ),
      SettingsEntriesCompanion.insert(key: _kScheduledExportEnabled, value: s.scheduledExportEnabled.toString()),
      SettingsEntriesCompanion.insert(key: _kScheduledExportFrequency, value: s.scheduledExportFrequency.name),
      SettingsEntriesCompanion.insert(key: _kScheduledExportMinute, value: s.scheduledExportMinute.toString()),
      SettingsEntriesCompanion.insert(key: _kScheduledExportWeekday, value: s.scheduledExportWeekday.toString()),
      SettingsEntriesCompanion.insert(key: _kScheduledExportFolderUri, value: s.scheduledExportFolderUri ?? ''),
      SettingsEntriesCompanion.insert(key: _kScheduledExportPassphraseSet, value: s.scheduledExportPassphraseSet.toString()),
      SettingsEntriesCompanion.insert(key: _kScheduledExportIncludeRawText, value: s.scheduledExportIncludeRawText.toString()),
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

    // Rows written before #63 have no quiet-hours keys; a corrupt value
    // falls back rather than throwing on every settings read.
    int minuteOr(String? raw, int fallback) {
      final v = int.tryParse(raw ?? '');
      return v != null && v >= 0 && v < 24 * 60 ? v : fallback;
    }

    int boundedInt(String? raw, int min, int max, int fallback) {
      final v = int.tryParse(raw ?? '');
      return (v != null && v >= min && v <= max) ? v : fallback;
    }

    return AppSettings(
      name: map[_kName] ?? defaults.name,
      accent: map[_kAccent] != null
          ? Color(int.parse(map[_kAccent]!))
          : defaults.accent,
      themeMode: byName(
        map[_kThemeMode],
        AppThemeMode.values,
        defaults.themeMode,
      ),
      homeHeadline: byName(
        map[_kHomeHeadline],
        HomeHeadline.values,
        defaults.homeHeadline,
      ),
      homeSections:
      map[_kHomeSections] != null && map[_kHomeSections]!.isNotEmpty
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
      autoAcceptCaptures: boolOr(
        map[_kAutoAccept],
        defaults.autoAcceptCaptures,
      ),
      bannerEnabled: boolOr(map[_kBannerEnabled], defaults.bannerEnabled),
      bannerHeadline: byName(
        map[_kBannerHeadline],
        BannerHeadline.values,
        defaults.bannerHeadline,
      ),
      bannerUnitIds: (map[_kBannerUnitIds] ?? '').isEmpty
          ? <String>{}
          : map[_kBannerUnitIds]!.split(',').toSet(),
      // Installs from before #86 have no mode key. Their intent is
      // recoverable from bannerUnitIds alone: any ids meant "these",
      // none meant "all" — the two readings the old code had. So an
      // upgrade keeps doing what it did.
      bannerUnitsMode: map[_kBannerUnitsMode] != null
          ? byName(
        map[_kBannerUnitsMode],
        BannerUnitsMode.values,
        defaults.bannerUnitsMode,
      )
          : (map[_kBannerUnitIds]?.isNotEmpty == true
          ? BannerUnitsMode.selected
          : defaults.bannerUnitsMode),
      bannerShowProgress: boolOr(
        map[_kBannerProgress],
        defaults.bannerShowProgress,
      ),
      bannerShowQuickAdd: boolOr(
        map[_kBannerQuickAdd],
        defaults.bannerShowQuickAdd,
      ),
      summaryNotificationsEnabled: boolOr(map[_kSummaryEnabled], defaults.summaryNotificationsEnabled),
      summaryDailyEnabled: boolOr(map[_kSummaryDailyEnabled], defaults.summaryDailyEnabled),
      summaryDailyMinute: minuteOr(map[_kSummaryDailyMinute], defaults.summaryDailyMinute),
      summaryWeeklyEnabled: boolOr(map[_kSummaryWeeklyEnabled], defaults.summaryWeeklyEnabled),
      summaryWeeklyWeekday: boundedInt(map[_kSummaryWeeklyWeekday], 1, 7, defaults.summaryWeeklyWeekday),
      summaryWeeklyMinute: minuteOr(map[_kSummaryWeeklyMinute], defaults.summaryWeeklyMinute),
      summaryMonthlyEnabled: boolOr(map[_kSummaryMonthlyEnabled], defaults.summaryMonthlyEnabled),
      summaryMonthlyDay: boundedInt(map[_kSummaryMonthlyDay], 1, 28, defaults.summaryMonthlyDay),
      summaryMonthlyMinute: minuteOr(map[_kSummaryMonthlyMinute], defaults.summaryMonthlyMinute),
      alertsEnabled: boolOr(map[_kAlertsEnabled], defaults.alertsEnabled),
      quietHoursEnabled: boolOr(
        map[_kQuietEnabled],
        defaults.quietHoursEnabled,
      ),
      quietStartMinute: minuteOr(map[_kQuietStart], defaults.quietStartMinute),
      quietEndMinute: minuteOr(map[_kQuietEnd], defaults.quietEndMinute),
      // Rows exist but carry no onboarding key: this install predates #7
      // (or was restored from a backup), so the person has already been
      // through setup. Only a truly empty table (above) means "first run".
      onboardingComplete: boolOr(map[_kOnboardingComplete], true),
      //#81 — default is "not hidden".
      amountsHidden: boolOr(map[_kHideAmounts], defaults.amountsHidden),
      // #28. Rows written before this change have no key: the
      // default is off, which is also what an upgrade should do —
      // nobody gets locked out of an app they never asked to lock.
      appLockEnabled: boolOr(map[_kAppLockEnabled], defaults.appLockEnabled),
      appLockBiometric: boolOr(
        map[_kAppLockBiometric],
        defaults.appLockBiometric,
      ),
      widgetUnitsMode: byName(
        map[_kWidgetUnitsMode],
        BannerUnitsMode.values,
        defaults.widgetUnitsMode,
      ),
      widgetUnitIds: (map[_kWidgetUnitIds] ?? '').isEmpty
          ? <String>{}
          : map[_kWidgetUnitIds]!.split(',').toSet(),
      widgetHeadline: byName(
        map[_kWidgetHeadline],
        BannerHeadline.values,
        defaults.widgetHeadline,
      ),
      widgetShowProgress: boolOr(
        map[_kWidgetProgress],
        defaults.widgetShowProgress,
      ),
      widgetShowSplit: boolOr(
        map[_kWidgetSplit],
        defaults.widgetShowSplit,
      ),
      widgetVariant: byName(
        map[_kWidgetVariant],
        WidgetVariant.values,
        defaults.widgetVariant,
      ),
      // Fll back rather than letting an empty string reach
// NumberFormat.simpleCurrency.
      currencyCode: (map[_kCurrencyCode]?.trim().isNotEmpty ?? false)
          ? map[_kCurrencyCode]!
          : defaults.currencyCode,
      scheduledExportEnabled: boolOr(map[_kScheduledExportEnabled], defaults.scheduledExportEnabled),
      scheduledExportFrequency: byName(
        map[_kScheduledExportFrequency],
        ScheduledExportFrequency.values,
        defaults.scheduledExportFrequency,
      ),
      scheduledExportMinute: minuteOr(map[_kScheduledExportMinute], defaults.scheduledExportMinute),
      scheduledExportWeekday: boundedInt(
        map[_kScheduledExportWeekday], 1, 7, defaults.scheduledExportWeekday,
      ),
      scheduledExportFolderUri:
      (map[_kScheduledExportFolderUri]?.isEmpty ?? true)
          ? null
          : map[_kScheduledExportFolderUri],
      scheduledExportPassphraseSet: boolOr(
        map[_kScheduledExportPassphraseSet],
        defaults.scheduledExportPassphraseSet,
      ),
      scheduledExportIncludeRawText: boolOr(
        map[_kScheduledExportIncludeRawText],
        defaults.scheduledExportIncludeRawText,
      ),
    );
  }
}

class DriftTemplateRepository implements TemplateRepository {
  DriftTemplateRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<CaptureTemplate>> watchTemplates({String? unitId}) {
    final query = _db.select(_db.templates)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    final wantedUnitId = unitId;
    if (wantedUnitId != null) {
      query.where((t) => t.unitId.equals(wantedUnitId));
    }
    return query.watch().map((rows) => rows.map(templateFromRow).toList());
  }

  @override
  Future<void> saveTemplate(CaptureTemplate template) {
    return _db
        .into(_db.templates)
        .insertOnConflictUpdate(templateToCompanion(template));
  }

  @override
  Future<void> deleteTemplate(String templateId) {
    return (_db.delete(
      _db.templates,
    )..where((t) => t.id.equals(templateId))).go();
  }
}

/// Unparsed captures (#21): the review inbox's "Couldn't read these"
/// list. Insert and 7-day purge run in one transaction so the table can
/// never grow without bound, whichever happens first.
class DriftCaptureRepository implements CaptureRepository {
  DriftCaptureRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<UnparsedCapture>> watchUnparsed() {
    final query = _db.select(_db.unparsedCaptures)
      ..orderBy([(u) => OrderingTerm.desc(u.receivedAt)]);
    return query.watch().map(
          (rows) => rows.map(unparsedCaptureFromRow).toList(),
    );
  }

  @override
  Future<void> recordUnparsed({
    required String id,
    required String sourcePackage,
    required String rawText,
  }) {
    return _db.transaction(() async {
      await _db
          .into(_db.unparsedCaptures)
          .insert(
        UnparsedCapturesCompanion.insert(
          id: id,
          receivedAt: DateTime.now().toUtc(),
          sourcePackage: sourcePackage,
          rawText: rawText,
        ),
      );
      // Time-based purge (issue #74): 14 days, matching the copy on the
      // review inbox.
      final cutoff = DateTime.now().toUtc().subtract(unparsedCaptureRetention);
      await (_db.delete(
        _db.unparsedCaptures,
      )..where((u) => u.receivedAt.isSmallerThanValue(cutoff))).go();

      // Size cap: keep only the newest N by receivedAt. A busy phone with
      // an unfamiliar bank format could otherwise grow this without bound
      // until the time purge catches up.
      final keepIds =
      await (_db.selectOnly(_db.unparsedCaptures)
        ..addColumns([_db.unparsedCaptures.id])
        ..orderBy([OrderingTerm.desc(_db.unparsedCaptures.receivedAt)])
        ..limit(unparsedCaptureCap))
          .map((row) => row.read(_db.unparsedCaptures.id)!)
          .get();
      await (_db.delete(
        _db.unparsedCaptures,
      )..where((u) => u.id.isNotIn(keepIds))).go();
    });
  }

  @override
  Future<void> deleteUnparsed(String captureId) {
    return (_db.delete(
      _db.unparsedCaptures,
    )..where((u) => u.id.equals(captureId))).go();
  }
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
      ..where((c) => c.archived.equals(false))
      ..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.name),
      ]))
        .watch()
        .map((rows) => rows.map(categoryFromRow).toList());
  }

  @override
  Stream<List<Category>> watchCategoriesIncludingArchived() {
    return (_db.select(_db.categories)..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.name),
    ]))
        .watch()
        .map((rows) => rows.map(categoryFromRow).toList());
  }

  @override
  Future<void> saveCategory(Category category) {
    return _db
        .into(_db.categories)
        .insertOnConflictUpdate(categoryToCompanion(category));
  }

  @override
  Future<void> archiveCategory(String categoryId) {
    return (_db.update(_db.categories)
      ..where((c) => c.id.equals(categoryId)))
        .write(const CategoriesCompanion(archived: Value(true)));
  }

  @override
  Future<void> unarchiveCategory(String categoryId) {
    return (_db.update(_db.categories)
      ..where((c) => c.id.equals(categoryId)))
        .write(const CategoriesCompanion(archived: Value(false)));
  }
}

/// The notification allow-list (#22). `insertOnConflictUpdate` is an
/// `INSERT ... ON CONFLICT DO UPDATE`, not a delete-and-insert, so saving
/// a source that a template already points at can't trip the foreign key.
class DriftCaptureSourceRepository implements CaptureSourceRepository {
  DriftCaptureSourceRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<CaptureSource>> watchSources() {
    final query = _db.select(_db.captureSources)
      ..orderBy([(s) => OrderingTerm.asc(s.displayName)]);
    return query.watch().map((rows) => rows.map(captureSourceFromRow).toList());
  }

  @override
  Future<void> saveSource(CaptureSource source) {
    return _db
        .into(_db.captureSources)
        .insertOnConflictUpdate(captureSourceToCompanion(source));
  }
}

class DriftOutingRepository implements OutingRepository {
  DriftOutingRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Outing>> watchOutings() {
    return (_db.select(_db.outings)
      ..orderBy([(o) => OrderingTerm.desc(o.startAt)]))
        .watch()
        .map((rows) => rows.map(outingFromRow).toList());
  }

  @override
  Future<void> saveOuting(Outing outing) =>
      _db.into(_db.outings).insertOnConflictUpdate(outingToCompanion(outing));

  @override
  Future<void> deleteOuting(String outingId) =>
      (_db.delete(_db.outings)..where((o) => o.id.equals(outingId))).go();

  @override
  Future<void> endOutingNow(String outingId) async {
    // Both fields in one write. An "ending" is one operation, not two, and
    // the reason this method exists (rather than the caller doing two
    // updates) is that the two must land together: an outing with
    // enabled=false but endAt in the future would still be "ended" for
    // the banner (banner checks isActive which checks enabled), but the
    // Past/Active lists would disagree about when it ended.
    final now = DateTime.now();
    await (_db.update(_db.outings)..where((o) => o.id.equals(outingId)))
        .write(OutingsCompanion(
      enabled: const Value(false),
      endAt: Value(now),
    ));
  }
}