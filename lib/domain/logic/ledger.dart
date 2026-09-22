import '../models/limit_rule.dart';
import '../models/transaction.dart';
import '../models/unit.dart';

/// Pure functions only — no Flutter, no I/O — so these are unit-testable
/// without a device (design.md section 1, "domain layer is pure Dart").
class Ledger {
  /// Balance = opening + sum of signed amounts over CONFIRMED transactions
  /// for that unit. Never stored; always derived (ADR-004).
  static int balanceOf(MoneyUnit unit, Iterable<MoneyTransaction> all) {
    var total = unit.openingBalanceMinor;
    for (final t in all) {
      if (t.unitId == unit.id && t.isConfirmed) {
        total += t.amountMinor;
      }
    }
    return total;
  }

  /// Total spent (positive number) across confirmed `spent` transactions
  /// in [from, to). `moved` is excluded by construction (only `spent`
  /// rows are summed) — see ADR-005.
  static int spentInPeriod(
      Iterable<MoneyTransaction> all,
      DateTime from,
      DateTime to, {
        String? unitId,
      }) {
    var total = 0;
    for (final t in all) {
      if (!t.countsAsSpending) continue;
      if (unitId != null && t.unitId != unitId) continue;
      if (t.occurredAt.isBefore(from) || !t.occurredAt.isBefore(to)) continue;
      total += -t.amountMinor; // amountMinor is negative for spending
    }
    return total;
  }

  static int gotInPeriod(
      Iterable<MoneyTransaction> all,
      DateTime from,
      DateTime to, {
        String? unitId,
      }) {
    var total = 0;
    for (final t in all) {
      if (!t.countsAsIncome) continue;
      if (unitId != null && t.unitId != unitId) continue;
      if (t.occurredAt.isBefore(from) || !t.occurredAt.isBefore(to)) continue;
      total += t.amountMinor;
    }
    return total;
  }

  /// [start, end) for "today" in local time.
  static (DateTime, DateTime) todayRange(DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return (start, start.add(const Duration(days: 1)));
  }

  /// [start, end) for the current calendar week, Monday-start.
  static (DateTime, DateTime) weekRange(DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day);
    final start = startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
    return (start, start.add(const Duration(days: 7)));
  }

  /// [start, end) for the current calendar month.
  static (DateTime, DateTime) monthRange(DateTime now) {
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return (start, end);
  }

  static SpendStatus statusFor(LimitRule? limit, int spentMinor) {
    if (limit == null || !limit.enabled) return SpendStatus.safe;
    return limit.statusFor(spentMinor);
  }
}