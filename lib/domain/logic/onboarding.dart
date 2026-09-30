// ---------------------------------------------------------------------------
// Onboarding (issue #7, ui-design-brief.md 7.1).
//
// Pure Dart, no widgets: the flow collects answers into an [OnboardingDraft]
// and nothing is written until the person finishes (or skips out). This file
// decides *what* gets written; OnboardingScreen decides when.
//
// Like settings.dart and unit.dart this uses Flutter's `Color` type — the
// "pure domain" rule is about not importing widgets.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../models/limit_rule.dart';
import '../models/money.dart';
import '../models/settings.dart';
import '../models/unit.dart';

/// Everything the person has told us so far. Immutable; every answer is
/// optional, because every step can be skipped.
@immutable
class OnboardingDraft {
  /// Onboarding is KES-only, matching the unit sheet (edit_unit_sheet.dart):
  /// multi-currency is future work.
  static const currencyCode = 'KES';

  final String name;
  final Color accent;

  /// Units added in step 2, in the order they were added. They are complete
  /// [MoneyUnit]s (id, opening balance and all) but not yet saved.
  final List<MoneyUnit> units;

  /// Daily limit in KES minor units; null means "I'll decide later".
  final int? dailyLimitMinor;

  /// Whether the person said yes to the ongoing banner.
  final bool bannerOn;

  const OnboardingDraft({
    this.name = '',
    this.accent = AppAccents.teal,
    this.units = const [],
    this.dailyLimitMinor,
    this.bannerOn = false,
  });

  OnboardingDraft copyWith({
    String? name,
    Color? accent,
    List<MoneyUnit>? units,
    bool? bannerOn,
  }) {
    return OnboardingDraft(
      name: name ?? this.name,
      accent: accent ?? this.accent,
      units: units ?? this.units,
      dailyLimitMinor: dailyLimitMinor,
      bannerOn: bannerOn ?? this.bannerOn,
    );
  }

  /// A separate method because null is a meaningful value here (copyWith
  /// can't tell "leave it" from "clear it").
  OnboardingDraft withDailyLimit(int? minor) {
    return OnboardingDraft(
      name: name,
      accent: accent,
      units: units,
      dailyLimitMinor: minor,
      bannerOn: bannerOn,
    );
  }

  /// Adds [unit], or replaces the draft unit with the same id.
  OnboardingDraft withUnit(MoneyUnit unit) {
    final next = [...units];
    final i = next.indexWhere((u) => u.id == unit.id);
    if (i >= 0) {
      next[i] = unit;
    } else {
      next.add(unit);
    }
    return copyWith(units: next);
  }

  OnboardingDraft withoutUnit(String unitId) =>
      copyWith(units: units.where((u) => u.id != unitId).toList());

  /// The daily limit to save, or null when the step was skipped. Alert
  /// levels follow whatever limits already exist (none, on a fresh
  /// install), exactly like the Limits screen does for a new limit.
  LimitRule? dailyLimit([Iterable<LimitRule> existing = const []]) {
    final minor = dailyLimitMinor;
    if (minor == null || minor <= 0) return null;
    final (warn, danger) = LimitRule.levelsFrom(existing);
    return LimitRule(
      id: LimitRule.idFor(LimitScope.overall, LimitPeriod.day),
      scope: LimitScope.overall,
      period: LimitPeriod.day,
      amountMinor: minor,
      currencyCode: currencyCode,
      warnAt: warn,
      dangerAt: danger,
    );
  }

  /// [base] with the answers applied and onboarding marked done. An empty
  /// name stays empty (Home then greets them without one) rather than
  /// keeping the development placeholder in [AppSettings.defaults].
  AppSettings settingsFor(AppSettings base) {
    return base.copyWith(
      name: name.trim(),
      accent: accent,
      bannerEnabled: bannerOn,
      onboardingComplete: true,
    );
  }
}

/// The big-number stepper on the daily-limit step. Whole shillings; the
/// step grows with the number so going from 1,000 to 5,000 isn't forty taps.
class LimitStepper {
  LimitStepper._();

  static const initial = 1000;
  static const min = 100;
  static const max = 1000000;

  /// Quick-pick amounts offered under the stepper.
  static const presets = <int>[500, 1000, 2000, 5000];

  static int _stepAt(int v) => v < 1000
      ? 100
      : v < 10000
      ? 500
      : 1000;

  /// One step up. Symmetrical with [down]: up then down returns to the
  /// start for any value this stepper produces.
  static int up(int v) => (v + _stepAt(v)).clamp(min, max).toInt();

  static int down(int v) => (v - _stepAt(v - 1)).clamp(min, max).toInt();

  /// Whole shillings to the minor units the limit is stored in.
  static int toMinor(int majorUnits) =>
      majorUnits * pow10(minorUnitExponent(OnboardingDraft.currencyCode));

  /// "1,000" style, for the big number.
  static String format(int majorUnits) =>
      Money(toMinor(majorUnits), OnboardingDraft.currencyCode)
          .format()
          .replaceAll(RegExp(r'\.0+$'), '');
}