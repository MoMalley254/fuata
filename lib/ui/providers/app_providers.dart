import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_repositories.dart';
import '../../domain/logic/ledger.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/repositories/repositories.dart';

/// Swap these three overrides for drift-backed repos in issue #13.
/// No screen below needs to change when that happens.
final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  return MockUnitRepository();
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return MockTransactionRepository();
});

final limitRepositoryProvider = Provider<LimitRepository>((ref) {
  return MockLimitRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return MockSettingsRepository();
});

final unitsProvider = StreamProvider<List<MoneyUnit>>((ref) {
  return ref.watch(unitRepositoryProvider).watchUnits();
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

  const HomeState({
    required this.units,
    required this.balanceByUnit,
    required this.spentToday,
    required this.dailyLimit,
    required this.status,
    required this.lately,
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

  final dailyLimit = limits
      .where((l) => l.scope == LimitScope.overall && l.period == LimitPeriod.day)
      .firstOrNull;

  final status = Ledger.statusFor(dailyLimit, spentToday);

  final lately = List<MoneyTransaction>.from(transactions)
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  return AsyncValue.data(HomeState(
    units: units,
    balanceByUnit: balances,
    spentToday: spentToday,
    dailyLimit: dailyLimit,
    status: status,
    lately: lately.take(3).toList(),
  ));
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}