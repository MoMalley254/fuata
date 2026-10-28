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
  ///
  /// Issue #108: [now] is normalised with `.toLocal()` before its calendar
  /// fields are read. `DateTime(y, m, d)` always builds a *local* midnight,
  /// so feeding it a UTC `now`'s `.year/.month/.day` picked the UTC calendar
  /// day — in EAT (UTC+3) that is the wrong day between 00:00 and 03:00.
  ///
  /// [end] is built with the calendar constructor, not `start + 24h`: a
  /// local day is 23 or 25 hours long across a DST change, and a fixed
  /// 24-hour offset would clip the last hour or leak into the next day.
  static (DateTime, DateTime) todayRange(DateTime now) {
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, local.day);
    return (start, DateTime(start.year, start.month, start.day + 1));
  }

  /// [start, end) for the current calendar week, Monday-start.
  ///
  /// Same local-day normalisation and calendar arithmetic as [todayRange]
  /// (#108); a week containing a DST change is not exactly 168 hours.
  static (DateTime, DateTime) weekRange(DateTime now) {
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, local.day - (local.weekday - 1));
    return (start, DateTime(start.year, start.month, start.day + 7));
  }

  /// [start, end) for the current calendar month.
  ///
  /// [now] is normalised to local first (#108); the constructor already
  /// rolls month 13 over into January of the next year.
  static (DateTime, DateTime) monthRange(DateTime now) {
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, 1);
    final end = DateTime(local.year, local.month + 1, 1);
    return (start, end);
  }

  static SpendStatus statusFor(LimitRule? limit, int spentMinor) {
    if (limit == null || !limit.enabled) return SpendStatus.safe;
    return limit.statusFor(spentMinor);
  }

  /// Spending per day for the last [days] days, oldest first, today last.
  ///
  /// Same "confirmed spending only" rule as [spentInPeriod]: `moved`,
  /// `adjustment` and `pending` rows are all excluded, so the strip can never
  /// disagree with the summary it opens (findings F6; testing.md S-20 to S-23).
  ///
  /// [now] is injectable so tests can pin the window; production callers
  /// leave it out. Boundaries are local calendar days — a transaction at
  /// 23:59 belongs to the day it happened, not the day it was confirmed.
  ///
  /// Issue #109: an `occurredAt` stored as UTC (the parser's ISO 8601
  /// branch, a backup import) is normalised with `.toLocal()` before its
  /// calendar fields are read. A 23:00 UTC payment in EAT (UTC+3) is 02:00
  /// the next day locally, and must land in *that* day's bar, not the
  /// UTC day's. [now] is normalised the same way, so a UTC `now` passed by
  /// a test or a background caller can't skew the window either.
  static List<int> spentByDay(
      Iterable<MoneyTransaction> all, {
        required DateTime now,
        int days = 7,
      }) {
    final nowLocal = now.toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final start = today.subtract(Duration(days: days - 1));
    final out = List<int>.filled(days, 0);

    for (final t in all) {
      if (!t.countsAsSpending) continue;
      final at = t.occurredAt.toLocal();
      final day = DateTime(at.year, at.month, at.day);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      out[day.difference(start).inDays] += -t.amountMinor;
    }
    return out;
  }
}