// Onboarding (issue #7): what the collected answers turn into, and the
// daily-limit stepper. Pure Dart — no widgets, no database.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/backup_codec.dart';
import 'package:fuata/domain/logic/onboarding.dart';
import 'package:fuata/domain/models/backup_snapshot.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/unit.dart';

MoneyUnit unit(String id, {String name = 'Cash', int opening = 0}) => MoneyUnit(
  id: id,
  name: name,
  kind: UnitKind.cash,
  currencyCode: 'KES',
  iconEmoji: '💵',
  color: const Color(0xFF2E9E6B),
  openingBalanceMinor: opening,
  sortOrder: 0,
  createdAt: DateTime(2026, 9, 30),
);

void main() {
  group('LimitStepper', () {
    test('steps grow with the number', () {
      expect(LimitStepper.up(900), 1000);
      expect(LimitStepper.up(1000), 1500);
      expect(LimitStepper.up(9500), 10000);
      expect(LimitStepper.up(10000), 11000);
    });

    test('down mirrors up at every boundary', () {
      expect(LimitStepper.down(1000), 900);
      expect(LimitStepper.down(1500), 1000);
      expect(LimitStepper.down(10000), 9500);
      expect(LimitStepper.down(11000), 10000);
    });

    test('stays inside its bounds', () {
      expect(LimitStepper.down(LimitStepper.min), LimitStepper.min);
      expect(LimitStepper.up(LimitStepper.max), LimitStepper.max);
    });

    test('walking up and back down returns to the start', () {
      final climbed = <int>[LimitStepper.min];
      while (climbed.last < 30000) {
        climbed.add(LimitStepper.up(climbed.last));
      }
      var v = climbed.last;
      for (final expected in climbed.reversed.skip(1)) {
        v = LimitStepper.down(v);
        expect(v, expected);
      }
    });

    test('every preset is reachable by the stepper', () {
      for (final p in LimitStepper.presets) {
        var v = LimitStepper.min;
        while (v < p) {
          v = LimitStepper.up(v);
        }
        expect(v, p, reason: '$p should be a stop on the way up');
      }
    });

    test('formats for the big number and converts to minor units', () {
      expect(LimitStepper.format(1000, 'KES'), '1,000');
      expect(LimitStepper.format(500, 'KES'), '500');
      expect(LimitStepper.format(25000, 'KES'), '25,000');
      expect(LimitStepper.toMinor(1000, 'KES'), 100000);
    });
  });

  group('OnboardingDraft', () {
    test('starts empty, with the default accent', () {
      const d = OnboardingDraft();
      expect(d.name, '');
      expect(d.accent, AppAccents.teal);
      expect(d.units, isEmpty);
      expect(d.dailyLimitMinor, isNull);
      expect(d.bannerOn, isFalse);
    });

    test('withUnit adds, then replaces by id, keeping order', () {
      var d = const OnboardingDraft()
          .withUnit(unit('a', name: 'Cash'))
          .withUnit(unit('b', name: 'Bank'));
      d = d.withUnit(unit('a', name: 'Wallet', opening: 5000));

      expect(d.units.map((u) => u.id), ['a', 'b']);
      expect(d.units.first.name, 'Wallet');
      expect(d.units.first.openingBalanceMinor, 5000);
    });

    test('withoutUnit removes only that unit', () {
      final d = const OnboardingDraft()
          .withUnit(unit('a'))
          .withUnit(unit('b'))
          .withoutUnit('a');
      expect(d.units.map((u) => u.id), ['b']);
    });

    test('no limit when the step was skipped', () {
      expect(const OnboardingDraft().dailyLimit(), isNull);
      expect(const OnboardingDraft().withDailyLimit(0).dailyLimit(), isNull);
    });

    test('a chosen limit becomes the overall daily rule', () {
      final limit = const OnboardingDraft().withDailyLimit(200000).dailyLimit();
      expect(limit, isNotNull);
      expect(limit!.id, LimitRule.idFor(LimitScope.overall, LimitPeriod.day));
      expect(limit.scope, LimitScope.overall);
      expect(limit.period, LimitPeriod.day);
      expect(limit.amountMinor, 200000);
      expect(limit.currencyCode, 'KES');
      expect(limit.enabled, isTrue);
      expect(limit.warnAt, 0.7);
      expect(limit.dangerAt, 0.9);
    });

    test('a new limit follows the alert levels already chosen', () {
      const existing = LimitRule(
        id: 'l_overall_week',
        scope: LimitScope.overall,
        period: LimitPeriod.week,
        amountMinor: 1,
        currencyCode: 'KES',
        warnAt: 0.5,
        dangerAt: 0.8,
      );
      final limit = const OnboardingDraft()
          .withDailyLimit(100000)
          .dailyLimit(const [existing]);
      expect(limit!.warnAt, 0.5);
      expect(limit.dangerAt, 0.8);
    });

    test('other edits keep the limit; withDailyLimit(null) clears it', () {
      final d = const OnboardingDraft().withDailyLimit(100000);
      expect(d.copyWith(name: 'Amina').dailyLimitMinor, 100000);
      expect(d.copyWith(bannerOn: true).dailyLimitMinor, 100000);
      expect(d.withUnit(unit('a')).dailyLimitMinor, 100000);
      expect(d.withDailyLimit(null).dailyLimitMinor, isNull);
    });

    test('settingsFor applies the answers and marks onboarding done', () {
      final base = AppSettings.defaults.copyWith(
        detailLevel: DetailLevel.detailed,
        redactedLockScreenBanner: false,
      );
      final s = const OnboardingDraft(
        name: '  Wanjiru ',
        accent: AppAccents.coral,
        bannerOn: true,
      ).settingsFor(base);

      expect(s.name, 'Wanjiru');
      expect(s.accent, AppAccents.coral);
      expect(s.bannerEnabled, isTrue);
      expect(s.onboardingComplete, isTrue);
      // Everything they weren't asked about is left alone.
      expect(s.detailLevel, DetailLevel.detailed);
      expect(s.redactedLockScreenBanner, isFalse);
    });

    test('a skipped name stays empty instead of the placeholder', () {
      final s = const OnboardingDraft().settingsFor(AppSettings.defaults);
      expect(s.name, '');
      expect(s.bannerEnabled, isFalse);
      expect(s.onboardingComplete, isTrue);
    });
  });

  test('settings restored from a backup never send anyone to onboarding', () {
    final file = BackupCodec.encode(
      BackupSnapshot(settings: AppSettings.defaults),
      exportedAt: DateTime.utc(2026, 9, 30),
    );
    final decoded = BackupCodec.decode(file);

    expect(decoded.errors, isEmpty);
    // AppSettings.defaults says "not onboarded" (a fresh install); a
    // backup only exists for an app that was set up.
    expect(AppSettings.defaults.onboardingComplete, isFalse);
    expect(decoded.snapshot!.settings!.onboardingComplete, isTrue);
  });
}
