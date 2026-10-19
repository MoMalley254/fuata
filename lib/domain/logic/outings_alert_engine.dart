// ---------------------------------------------------------------------------
// Limit alerts for outings (issue #30). Mirrors AlertEngine.due exactly,
// but over Outings instead of LimitRules, and using the outing's explicit
// window instead of a rolling period.
//
// Alert keys reuse AlertKey's shape — the "limitId" is the outing's id,
// the "periodKey" is the string "outing" (one period per outing, so no
// way to collide with a date-based key), and the level is the standard
// warning/danger/overdraft. A person crossing 70% of their trip budget
// gets the same nudge they'd get for 70% of their daily budget.
// ---------------------------------------------------------------------------
import '../models/limit_alert.dart';
import '../models/limit_rule.dart';
import '../models/outing.dart';
import '../models/transaction.dart';
import '../models/unit.dart';
import 'outings.dart';

class OutingAlertEngine {
  OutingAlertEngine._();

  static List<LimitAlert> due({
    required Iterable<Outing> outings,
    required List<MoneyUnit> units,
    required Iterable<MoneyTransaction> transactions,
    required Set<AlertKey> fired,
    required DateTime now,
  }) {
    final currencyByUnit = {
      for (final u in units) u.id: u.currencyCode,
    };
    final out = <LimitAlert>[];

    for (final outing in outings) {
      if (!outing.isActive(now)) continue;
      if (outing.amountMinor <= 0) continue;

      final spent = Outings.spentIn(
        outing,
        transactions,
        currencyByUnit: currencyByUnit,
      );
      final level = _levelFor(outing, spent);
      if (level == null) continue;

      final key = AlertKey(outing.id, 'outing', level);
      if (fired.contains(key)) continue;

      out.add(LimitAlert(
        limit: outing.asLimit(),
        level: level,
        periodKey: 'outing',
        spentMinor: spent,
        // #30: the alert's wording uses the outing's name — "you're
        // over this trip's limit" instead of "today's".
        periodLabel: "this trip's",
      ));
    }
    return out;
  }

  static AlertLevel? _levelFor(Outing outing, int spentMinor) =>
      switch (outing.asLimit().statusFor(spentMinor)) {
        SpendStatus.safe => null,
        SpendStatus.warning => AlertLevel.warning,
        SpendStatus.danger => AlertLevel.danger,
        SpendStatus.overdraft => AlertLevel.overdraft,
      };
}