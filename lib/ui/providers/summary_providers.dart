import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/summary.dart';
import 'app_providers.dart';

/// Issue #23: the summary for one period, recomputed whenever units or
/// transactions change.
///
/// The summary currency is the first unit's, the same rule Home uses for
/// its hero card; transactions on a unit in another currency are left out
/// instead of being added to it as if it were the same money (testing.md
/// T-13).
class SummaryData {
  final PeriodSummary summary;
  final String currencyCode;
  const SummaryData({required this.summary, required this.currencyCode});
}

final summaryProvider =
Provider.family<AsyncValue<SummaryData>, SummaryPeriod>((ref, period) {
  // "Today" and "this week" change at midnight even when no transaction
  // does (issue #107).
  ref.watch(midnightTickProvider);
  final unitsAsync = ref.watch(unitsProvider);
  final txAsync = ref.watch(transactionsProvider);

  if (unitsAsync.isLoading || txAsync.isLoading) {
    return const AsyncValue.loading();
  }
  final error = unitsAsync.error ?? txAsync.error;
  if (error != null) return AsyncValue.error(error, StackTrace.current);

  final units = unitsAsync.value ?? [];
  final currency = units.isNotEmpty ? units.first.currencyCode : 'KES';
  final currencyByUnit = {for (final u in units) u.id: u.currencyCode};

  final summary = PeriodSummary.build(
    txAsync.value ?? [],
    period,
    DateTime.now(),
    // A transaction on an archived unit has no entry here; it is still the
    // person's money, so only a *known* different currency is excluded.
    include: (t) {
      final unitCurrency = currencyByUnit[t.unitId];
      return unitCurrency == null || unitCurrency == currency;
    },
  );
  return AsyncValue.data(SummaryData(summary: summary, currencyCode: currency));
});