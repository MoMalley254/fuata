import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/backup_repository.dart';
import '../../data/db/drift_repositories.dart';
import '../../domain/logic/backup_service.dart';
import '../../domain/logic/ledger.dart';
import '../../domain/models/category.dart';
import '../../domain/models/limit_rule.dart';
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

  const HomeState({
    required this.units,
    required this.balanceByUnit,
    required this.spentToday,
    required this.dailyLimit,
    required this.status,
    required this.lately,
    this.spentByDay = const [0, 0, 0, 0, 0, 0, 0],
  });

  static const empty = HomeState(
    units: [],
    balanceByUnit: {},
    spentToday: 0,
    dailyLimit: null,
    status: SpendStatus.safe,
    lately: [],
  );

  int get leftToday =>
      dailyLimit == null ? 0 : dailyLimit!.amountMinor - spentToday;
}

final homeStateProvider = Provider<AsyncValue<HomeState>>((ref) {
  final unitsAsync = ref.watch(unitsProvider);
  final txAsync = ref.watch(transactionsProvider);
  final limitsAsync = ref.watch(limitsProvider);

  if (unitsAsync.isLoading || txAsync.isLoading || limitsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  final error = unitsAsync.error ?? txAsync.error ?? limitsAsync.error;
  if (error != null) return AsyncValue.error(error, StackTrace.current);

  final units = unitsAsync.value ?? [];
  final transactions = txAsync.value ?? [];
  final limits = limitsAsync.value ?? [];

  final balances = {
    for (final u in units) u.id: Ledger.balanceOf(u, transactions),
  };

  final now = DateTime.now();
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

  return AsyncValue.data(
    HomeState(
      units: units,
      balanceByUnit: balances,
      spentToday: spentToday,
      dailyLimit: dailyLimit,
      status: status,
      lately: lately.take(3).toList(),
      spentByDay: spentByDay
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
