enum LimitScope { overall, unit }

enum LimitPeriod { day, week, month }

/// Safe/Warning/Danger/Overdraft, matching thresholds in design.md
/// section 2 ("Derived values") and requirements.md section 5.
enum SpendStatus { safe, warning, danger, overdraft }

extension SpendStatusLabel on SpendStatus {
  String get emoji => switch (this) {
    SpendStatus.safe => '🟢',
    SpendStatus.warning => '🟡',
    SpendStatus.danger => '🟠',
    SpendStatus.overdraft => '🔴',
  };

  String get label => switch (this) {
    SpendStatus.safe => "You're good",
    SpendStatus.warning => 'Easy now',
    SpendStatus.danger => 'Almost at your limit',
    SpendStatus.overdraft => "You're over",
  };
}

class LimitRule {
  final String id;
  final LimitScope scope;
  final String? unitId; // null when scope == overall
  final LimitPeriod period;
  final int amountMinor;
  final String currencyCode;
  final double warnAt; // default 0.7
  final double dangerAt; // default 0.9
  final bool enabled;

  const LimitRule({
    required this.id,
    required this.scope,
    required this.period,
    required this.amountMinor,
    required this.currencyCode,
    this.unitId,
    this.warnAt = 0.7,
    this.dangerAt = 0.9,
    this.enabled = true,
  });

  /// Stable id for a limit: one row per (scope, unit, period), so saving
  /// again edits in place instead of adding a second limit.
  static String idFor(LimitScope scope, LimitPeriod period, [String? unitId]) =>
      scope == LimitScope.overall
          ? 'l_overall_${period.name}'
          : 'l_unit_${unitId}_${period.name}';

  /// The alert levels a *new* limit should start with: whatever the
  /// person already chose for their existing limits (they set these once,
  /// on the Limits screen), or the defaults when there are none.
  static (double, double) levelsFrom(Iterable<LimitRule> existing) {
    final first = existing.isEmpty ? null : existing.first;
    return (first?.warnAt ?? 0.7, first?.dangerAt ?? 0.9);
  }

  /// Given spent-so-far (positive minor units) and this limit, returns
  /// the status. Overdraft also applies whenever spent >= amount.
  SpendStatus statusFor(int spentMinor) {
    if (amountMinor <= 0) return SpendStatus.safe;
    final ratio = spentMinor / amountMinor;
    if (ratio >= 1.0) return SpendStatus.overdraft;
    if (ratio >= dangerAt) return SpendStatus.danger;
    if (ratio >= warnAt) return SpendStatus.warning;
    return SpendStatus.safe;
  }

  LimitRule copyWith({
    LimitScope? scope,
    String? unitId,
    LimitPeriod? period,
    int? amountMinor,
    String? currencyCode,
    double? warnAt,
    double? dangerAt,
    bool? enabled,
  }) {
    return LimitRule(
      id: id,
      scope: scope ?? this.scope,
      unitId: unitId ?? this.unitId,
      period: period ?? this.period,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      warnAt: warnAt ?? this.warnAt,
      dangerAt: dangerAt ?? this.dangerAt,
      enabled: enabled ?? this.enabled,
    );
  }
}