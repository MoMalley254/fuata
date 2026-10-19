import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/backup_repository.dart';
import '../../data/db/drift_repositories.dart';
import '../../domain/logic/backup_service.dart';
import '../../domain/logic/ledger.dart';
import '../../domain/logic/outings.dart';
import '../../domain/models/category.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/outing.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/template.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/repositories/repositories.dart';

/// One database for the app's lifetime. Opening the file is deferred
/// until the first query (AppDatabase wraps it in a LazyDatabase), so
/// creating this provider eagerly at startup is cheap.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Issue #13: these four now point at the real drift-backed repositories
/// instead of data/mock/mock_repositories.dart. No screen below needed to
/// change for the swap — they only ever depended on the interfaces in
/// domain/repositories/repositories.dart (design.md, "UI-first approach").
/// The mock repositories are kept around for widget tests/previews.
final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  return DriftUnitRepository(ref.watch(appDatabaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
});

final limitRepositoryProvider = Provider<LimitRepository>((ref) {
  return DriftLimitRepository(ref.watch(appDatabaseProvider));
});

/// Issue #63: which limit alerts have already been shown.
final alertLogRepositoryProvider = Provider<AlertLogRepository>((ref) {
  return DriftAlertLogRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(appDatabaseProvider));
});

/// Issue #24: whole-database export/import, and the service the Back up &
/// restore screen talks to. Not a stream — read once to export or plan,
/// written once (in a transaction) when the person confirms.
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return DriftBackupRepository(ref.watch(appDatabaseProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(backupRepositoryProvider));
});

/// Issue #20: templates built by the rule builder, persisted in the
/// Templates drift table that #13 created.
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return DriftTemplateRepository(ref.watch(appDatabaseProvider));
});

final templatesProvider = StreamProvider<List<CaptureTemplate>>((ref) {
  return ref.watch(templateRepositoryProvider).watchTemplates();
});

/// Templates for one unit — used by the unit page to show how many
/// reading rules a unit already has.
final unitTemplatesProvider =
    StreamProvider.family<List<CaptureTemplate>, String>((ref, unitId) {
      return ref
          .watch(templateRepositoryProvider)
          .watchTemplates(unitId: unitId);
    });

final unitsProvider = StreamProvider<List<MoneyUnit>>((ref) {
  return ref.watch(unitRepositoryProvider).watchUnits();
});

/// Every unit, archived ones included. History (Activity, transaction
/// detail) watches this so a row whose unit has been put away reads
/// "Cash (archived)" rather than "Unknown" (finding F9).
final allUnitsProvider = StreamProvider<List<MoneyUnit>>((ref) {
  return ref.watch(unitRepositoryProvider).watchUnits(includeArchived: true);
});

/// Just the archived ones, most recently archived first. Plain provider,
/// not a stream — it's derived from [allUnitsProvider] and falls back to
/// an empty list while the underlying stream is still loading, the same
/// shape as [pendingTransactionsProvider] and [allowedPackagesProvider].
///
/// Sorted by `archivedAt` when both units have it; when one doesn't (an
/// older backup, or a unit archived before the column existed), sortOrder
/// is the tiebreak so the list still has a stable order.
final archivedUnitsProvider = Provider<List<MoneyUnit>>((ref) {
  final all = ref.watch(allUnitsProvider).value ?? const <MoneyUnit>[];
  return all.where((u) => u.archived).toList()
    ..sort((a, b) {
      final ad = a.archivedAt;
      final bd = b.archivedAt;
      if (ad != null && bd != null) return bd.compareTo(ad);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
});

final transactionsProvider = StreamProvider<List<MoneyTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions();
});

final limitsProvider = StreamProvider<List<LimitRule>>((ref) {
  return ref.watch(limitRepositoryProvider).watchLimits();
});

/// Settings, with a synchronous-feeling default: screens that just want
/// "the current settings, or sensible defaults while loading" can read
/// `ref.watch(currentSettingsProvider)` instead of unwrapping an
/// AsyncValue every time (mirrors how HomeState hides its own loading).
final settingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

final currentSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).value ?? AppSettings.defaults;
});

/// Fires once at each local midnight so everything derived from "which
/// day is it" — Home, the banner, the alerts, the widget, Summary — rolls
/// over without the person doing anything (issue #107).
///
/// A Notifier rather than a StreamProvider<void>: a stream yielding `null`
/// emits an equal `AsyncData<void>` every time, and Riverpod's default
/// `==` comparison means only the first tick would notify watchers. An
/// incrementing int is always a new value.
class MidnightTicker extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    _schedule();
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  /// Recompute now, then re-arm for the next boundary. Called on app
  /// resume: a phone asleep across midnight never fired the timer, and
  /// resume is the moment the person will actually look at the screen.
  void refresh() {
    state = state + 1;
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    // DateTime normalises day overflow, so a month end and a year end are
    // handled without special cases.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    var delay = nextMidnight.difference(now);
    // A clock that hasn't moved (or was moved backwards) would give a
    // non-positive delay, and Timer(<=0) spins the isolate. A one-second
    // floor keeps the loop alive without hammering it.
    if (delay <= Duration.zero) delay = const Duration(seconds: 1);
    _timer?.cancel();
    _timer = Timer(delay, () {
      state = state + 1;
      _schedule();
    });
  }
}

final midnightTickProvider =
NotifierProvider<MidnightTicker, int>(MidnightTicker.new);

/// Everything Home needs, recomputed whenever units/transactions/limits
/// change. Kept as one bundle per the storage/perf note in the build
/// notes: fewer moving parts for the UI to juggle.
class HomeState {
  final List<MoneyUnit> units;
  final Map<String, int> balanceByUnit; // minor units
  final int spentToday;
  final LimitRule? dailyLimit;
  final SpendStatus status;
  final List<MoneyTransaction> lately;
  /// Spending for the last seven days, oldest first, today last (issue #82).
  /// Minor units. Computed here rather than in the widget so the strip and
  /// the summary it opens read from the same rule (Ledger.spentByDay).
  final List<int> spentByDay;

  /// #30: the outing that's active right now, or null.
  final Outing? activeOuting;
  /// Spending in the outing's window, in minor units.
  final int outingSpent;
  /// Outing status, or the daily status when no outing is active.
  final SpendStatus outingStatus;
  /// The outing's caption ("ends Fri 20:00"), or null when no outing.
  final String? outingCaption;

  const HomeState({
    required this.units,
    required this.balanceByUnit,
    required this.spentToday,
    required this.dailyLimit,
    required this.status,
    required this.lately,
    this.spentByDay = const [0, 0, 0, 0, 0, 0, 0],
    this.activeOuting,
    this.outingSpent = 0,
    this.outingStatus = SpendStatus.safe,
    this.outingCaption,
  });

  static const empty = HomeState(
    units: [],
    balanceByUnit: {},
    spentToday: 0,
    dailyLimit: null,
    status: SpendStatus.safe,
    lately: [],
  );

  // Effective values: the outing wins when active.
  SpendStatus get effectiveStatus =>
      activeOuting != null ? outingStatus : status;

  LimitRule? get effectiveLimit =>
      activeOuting != null ? activeOuting!.asLimit() : dailyLimit;

  int get effectiveSpent =>
      activeOuting != null ? outingSpent : spentToday;

  int get effectiveRemaining {
    if (activeOuting != null) return activeOuting!.amountMinor - outingSpent;
    if (dailyLimit == null) return 0;
    return dailyLimit!.amountMinor - spentToday;
  }

  int get leftToday =>
      dailyLimit == null ? 0 : dailyLimit!.amountMinor - spentToday;
}

final homeStateProvider = Provider<AsyncValue<HomeState>>((ref) {
  // Re-run on each midnight tick: without this a Home screen left open
  // across the boundary keeps showing yesterday's total and status until
  // something else changes (issue #107).
  ref.watch(midnightTickProvider);
  final unitsAsync = ref.watch(unitsProvider);
  final allUnitsAsync = ref.watch(allUnitsProvider);
  final txAsync = ref.watch(transactionsProvider);
  final limitsAsync = ref.watch(limitsProvider);
  final outingAsync = ref.watch(outingsProvider);

  if (unitsAsync.isLoading ||
      allUnitsAsync.isLoading ||
      txAsync.isLoading ||
      limitsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  final error = unitsAsync.error ??
      allUnitsAsync.error ??
      txAsync.error ??
      limitsAsync.error;
  if (error != null) return AsyncValue.error(error, StackTrace.current);

  final units = unitsAsync.value ?? [];
  final allUnits = allUnitsAsync.value ?? [];
  final transactions = txAsync.value ?? [];
  final limits = limitsAsync.value ?? [];
  final outings = outingAsync.value ?? const <Outing>[];

  final now = DateTime.now();

  final balances = {
    for (final u in units) u.id: Ledger.balanceOf(u, transactions),
  };

  final (start, end) = Ledger.todayRange(now);
  final spentToday = Ledger.spentInPeriod(transactions, start, end);
  final spentByDay = Ledger.spentByDay(transactions, now: now);

  final dailyLimit = limits
      .where(
        (l) =>
            l.enabled &&
            l.scope == LimitScope.overall &&
            l.period == LimitPeriod.day,
      )
      .firstOrNull;

  final status = Ledger.statusFor(dailyLimit, spentToday);

  final lately = List<MoneyTransaction>.from(transactions)
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  // #30: active outing (banner-gated? no — Home hero shows the outing
  // even if its banner is off; the banner flag only affects the
  // notification).
  final activeOuting = Outings.activeFrom(outings, now: now);
  int outingSpent = 0;
  SpendStatus outingStatus = SpendStatus.safe;
  String? outingCaption;
  if (activeOuting != null) {
    final currencyByUnit = {
      for (final u in allUnits) u.id: u.currencyCode,
    };
    outingSpent = Outings.spentIn(
      activeOuting,
      transactions,
      currencyByUnit: currencyByUnit,
    );
    outingStatus = Outings.statusFor(activeOuting, outingSpent);
    outingCaption = OutingState(
      outing: activeOuting,
      spentMinor: outingSpent,
      remainingMinor: activeOuting.amountMinor - outingSpent,
      status: outingStatus,
      isActive: true,
    ).caption(now);
  }

  return AsyncValue.data(
    HomeState(
      units: units,
      balanceByUnit: balances,
      spentToday: spentToday,
      dailyLimit: dailyLimit,
      status: status,
      lately: lately.take(3).toList(),
      spentByDay: spentByDay,
      activeOuting: activeOuting,
      outingSpent: outingSpent,
      outingStatus: outingStatus,
      outingCaption: outingCaption,
    ),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(ref.watch(appDatabaseProvider));
});

/// Active categories, ordered. The picker in the add and fix sheets and
/// the summary's per-category block both read this.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

/// Same, plus archived — the settings screen.
final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesIncludingArchived();
});

final outingRepositoryProvider = Provider<OutingRepository>((ref) {
  return DriftOutingRepository(ref.watch(appDatabaseProvider));
});

final outingsProvider = StreamProvider<List<Outing>>((ref) {
  return ref.watch(outingRepositoryProvider).watchOutings();
});

/// The outing that's active right now, or null. Recomputed on each
/// midnight tick so an outing that ends at 23:59 disappears exactly at
/// midnight without needing a settings write to trigger a rebuild.
final activeOutingProvider = Provider<Outing?>((ref) {
  ref.watch(midnightTickProvider);
  final outings = ref.watch(outingsProvider).value ?? const <Outing>[];
  return Outings.activeFrom(outings, now: DateTime.now());
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
