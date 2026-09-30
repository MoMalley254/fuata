// ---------------------------------------------------------------------------
// A limit alert (issue #63, US-06): "you've crossed a line on a limit".
//
// Pure Dart. The engine (logic/alert_engine.dart) decides *what is due*;
// the platform layer decides *how it is shown*. Nothing here knows about
// notifications.
// ---------------------------------------------------------------------------

import 'limit_rule.dart';

/// The three lines a limit can cross, in ascending order. These are the
/// friendly "Nudge me at 70% / 90% / when I'm over" levels of
/// ui-design-brief.md 7.8 — the first two thresholds are per limit
/// (`warnAt`, `dangerAt`), the third is always 100%.
enum AlertLevel { warning, danger, overdraft }

extension AlertLevelX on AlertLevel {
  SpendStatus get status => switch (this) {
    AlertLevel.warning => SpendStatus.warning,
    AlertLevel.danger => SpendStatus.danger,
    AlertLevel.overdraft => SpendStatus.overdraft,
  };

  /// This level plus every lower one. An alert that jumps straight to
  /// "over" also records "nudge" and "almost" as used, so they can't fire
  /// later in the same period for the same limit.
  List<AlertLevel> get andBelow => [
    for (final l in AlertLevel.values)
      if (l.index <= index) l,
  ];
}

/// Identity of one firing: this limit, in this period, at this level.
/// "Once per threshold per period" means at most one row per key.
class AlertKey {
  final String limitId;
  final String periodKey;
  final AlertLevel level;
  const AlertKey(this.limitId, this.periodKey, this.level);

  @override
  bool operator ==(Object other) =>
      other is AlertKey &&
      other.limitId == limitId &&
      other.periodKey == periodKey &&
      other.level == level;

  @override
  int get hashCode => Object.hash(limitId, periodKey, level);

  @override
  String toString() => 'AlertKey($limitId, $periodKey, ${level.name})';
}

/// One alert that is due to be shown.
class LimitAlert {
  final LimitRule limit;
  final AlertLevel level;
  final String periodKey;
  final int spentMinor;

  /// Name of the unit for a per-unit limit; null for an overall limit.
  final String? unitName;

  const LimitAlert({
    required this.limit,
    required this.level,
    required this.periodKey,
    required this.spentMinor,
    this.unitName,
  });

  AlertKey get key => AlertKey(limit.id, periodKey, level);

  /// Every key this alert uses up (its own level and the ones below).
  List<AlertKey> get consumedKeys => [
    for (final l in level.andBelow) AlertKey(limit.id, periodKey, l),
  ];
}
