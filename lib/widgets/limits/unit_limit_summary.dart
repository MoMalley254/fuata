import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../domain/models/unit.dart';

/// The per-unit limits of one unit, keyed by period.
Map<LimitPeriod, LimitRule> unitLimitsFor(
    Iterable<LimitRule> limits,
    String unitId,
    ) => {
  for (final l in limits)
    if (l.scope == LimitScope.unit && l.unitId == unitId) l.period: l,
};

/// "Daily KES 500 · Monthly KES 8,000", or "No limit set". Shared by the
/// Limits screen's "More" list and the unit page's limit row.
String unitLimitSummary(
    Iterable<LimitRule> limits,
    MoneyUnit unit, {
      bool masked = false,
    }) {
  final byPeriod = unitLimitsFor(limits, unit.id);
  final parts = <String>[
    for (final p in LimitPeriod.values)
      if (byPeriod[p] case final r?)
        '${_label(p)} '
            '${masked ? kHiddenAmountMask : Money(r.amountMinor, r.currencyCode).format()}'
            '${r.enabled ? '' : ' (paused)'}',
  ];
  return parts.isEmpty ? 'No limit set' : parts.join(' · ');
}

String _label(LimitPeriod p) => switch (p) {
  LimitPeriod.day => 'Daily',
  LimitPeriod.week => 'Weekly',
  LimitPeriod.month => 'Monthly',
};
