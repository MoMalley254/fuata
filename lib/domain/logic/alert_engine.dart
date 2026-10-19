// ---------------------------------------------------------------------------
// Deciding which limit alerts are due (issue #63, US-06).
//
// Pure functions, no I/O: given the limits, the transactions and what has
// already been shown, say what should be shown now. The same function runs
// in the UI isolate and in the notification listener's background isolate
// (via alert_service.dart), so an alert never depends on which of the two
// happened to see a transaction first.
//
// Rules (requirements.md US-06, ui-design-brief.md 7.8):
//  * One alert per limit per evaluation, for the *highest* level crossed
//    and not yet shown this period. Jumping from 50% to 105% shows "over",
//    not three notifications.
//  * Each (limit, period, level) fires at most once. Spending less again
//    (a deleted transaction) and re-crossing does not re-fire.
//  * A disabled limit never alerts.
// ---------------------------------------------------------------------------

import '../models/limit_alert.dart';
import '../models/limit_rule.dart';
import '../models/money.dart';
import '../models/transaction.dart';
import '../models/unit.dart';
import 'ledger.dart';

class AlertEngine {
  AlertEngine._();

  /// Identifies the period a limit is currently measuring, so "once per
  /// period" has something to key on: the date for a day, the Monday's
  /// date for a week (Monday-start, matching [Ledger.weekRange]), and
  /// year-month for a month.
  static String periodKey(LimitPeriod period, DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    final (start, _) = rangeFor(period, now);
    return switch (period) {
      LimitPeriod.day || LimitPeriod.week =>
      '${start.year}-${two(start.month)}-${two(start.day)}',
      LimitPeriod.month => '${start.year}-${two(start.month)}',
    };
  }

  static (DateTime, DateTime) rangeFor(LimitPeriod period, DateTime now) =>
      switch (period) {
        LimitPeriod.day => Ledger.todayRange(now),
        LimitPeriod.week => Ledger.weekRange(now),
        LimitPeriod.month => Ledger.monthRange(now),
      };

  /// The level [spentMinor] has reached on [limit], or null below the
  /// first threshold. Mirrors [LimitRule.statusFor] exactly, so the
  /// banner's emoji and the alert level can never disagree.
  static AlertLevel? levelFor(LimitRule limit, int spentMinor) =>
      switch (limit.statusFor(spentMinor)) {
        SpendStatus.safe => null,
        SpendStatus.warning => AlertLevel.warning,
        SpendStatus.danger => AlertLevel.danger,
        SpendStatus.overdraft => AlertLevel.overdraft,
      };

  /// What is due right now. [fired] is everything already shown.
  ///
  /// Overall limits count spending in the limit's own currency (design.md
  /// LIMIT_RULE, T-13): a KES limit is not eaten by USD spending. A
  /// transaction whose unit isn't in [units] (an archived one) is still
  /// counted, matching how Home and the banner treat archived history.
  /// Per-unit limits count that unit only, and are skipped when the unit
  /// is gone or archived.
  static List<LimitAlert> due({
    required List<LimitRule> limits,
    required List<MoneyUnit> units,
    required Iterable<MoneyTransaction> transactions,
    required Set<AlertKey> fired,
    required DateTime now,
  }) {
    final unitsById = {for (final u in units) u.id: u};
    final currencyOf = {for (final u in units) u.id: u.currencyCode};
    final out = <LimitAlert>[];

    for (final limit in limits) {
      if (!limit.enabled || limit.amountMinor <= 0) continue;

      String? unitName;
      String? unitId;
      if (limit.scope == LimitScope.unit) {
        final unit = unitsById[limit.unitId];
        if (unit == null || unit.archived) continue;
        unitName = unit.name;
        unitId = unit.id;
      }

      final (from, to) = rangeFor(limit.period, now);
      final counted = unitId != null
          ? transactions
          : transactions.where((t) {
        final code = currencyOf[t.unitId];
        return code == null || code == limit.currencyCode;
      });
      final spent = Ledger.spentInPeriod(counted, from, to, unitId: unitId);
      final level = levelFor(limit, spent);
      if (level == null) continue;

      final key = periodKey(limit.period, now);
      if (fired.contains(AlertKey(limit.id, key, level))) continue;

      out.add(LimitAlert(
        limit: limit,
        level: level,
        periodKey: key,
        spentMinor: spent,
        unitName: unitName,
      ));
    }
    return out;
  }
}

/// Quiet hours (ui-design-brief.md 7.8): a daily window in which alerts
/// still arrive, but without sound or a heads-up. Minutes after local
/// midnight; the window may wrap midnight (22:00 -> 07:00).
class QuietHours {
  QuietHours._();

  /// An empty window (start == end) is "never quiet", not "always quiet":
  /// silencing every alert because two pickers match would be a nasty
  /// surprise.
  static bool contains({
    required int startMinute,
    required int endMinute,
    required DateTime at,
  }) {
    if (startMinute == endMinute) return false;
    final m = at.hour * 60 + at.minute;
    if (startMinute < endMinute) return m >= startMinute && m < endMinute;
    return m >= startMinute || m < endMinute; // wraps midnight
  }
}

/// The words on an alert notification (ui-design-brief.md 7.10: "Easy now:
/// you've used 80% of today.").
class AlertText {
  AlertText._();

  static ({String title, String body}) build(LimitAlert a) {
    final limit = a.limit;
    final period = a.periodLabel ?? switch (limit.period) {
      LimitPeriod.day => "today's",
      LimitPeriod.week => "this week's",
      LimitPeriod.month => "this month's",
    };
    final where = a.unitName == null ? '' : ' on ${a.unitName}';
    final percent = limit.amountMinor <= 0
        ? 0
        : (a.spentMinor * 100 / limit.amountMinor).floor();

    return switch (a.level) {
      AlertLevel.warning => (
      title: '${a.level.status.emoji} Easy now',
      body: "You've used $percent% of $period limit$where.",
      ),
      AlertLevel.danger => (
      title: '${a.level.status.emoji} Almost at your limit',
      body: "You've used $percent% of $period limit$where.",
      ),
      AlertLevel.overdraft => (
      title: "${a.level.status.emoji} You're over",
      body: "You're over $period limit$where by "
          '${Money(a.spentMinor - limit.amountMinor, limit.currencyCode).format()}.',
      ),
    };
  }
}
