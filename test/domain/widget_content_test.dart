// Issue #29 and #113: the home-screen widget's snapshot. Pure Dart — the
// actual RemoteViews rendering is verified on device (#26), not here.
//
// This file replaces the pre-#113 version. The local `build` wrapper now
// mirrors WidgetSnapshot.build's full option set; `mockUnit` exists so
// the file doesn't collide with backup_test_data.dart's differently
// shaped `unit` helper.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/widget_content.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  final dayLimit = LimitRule(
    id: 'l_overall_day',
    scope: LimitScope.overall,
    period: LimitPeriod.day,
    amountMinor: 200000, // 2,000.00
    currencyCode: 'KES',
  );

  MoneyUnit mockUnit(String id, String name, int openingMinor) => MoneyUnit(
    id: id,
    name: name,
    kind: UnitKind.cash,
    currencyCode: 'KES',
    iconEmoji: '💵',
    color: const Color(0xFF2E9E6B),
    openingBalanceMinor: openingMinor,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );

  WidgetSnapshot build({
    required int spent,
    LimitRule? limit,
    String currency = 'KES',
    BannerHeadline headline = BannerHeadline.leftToday,
    BannerUnitsMode unitsMode = BannerUnitsMode.all,
    Set<String> selectedUnitIds = const {},
    bool showProgress = true,
    bool showSplit = false,
    WidgetVariant variant = WidgetVariant.auto,
    List<MoneyUnit> units = const [],
    Map<String, int> balanceByUnit = const {},
  }) =>
      WidgetSnapshot.build(
        status: limit == null ? SpendStatus.safe : limit.statusFor(spent),
        spentToday: spent,
        dailyLimit: limit,
        currencyCode: currency,
        headline: headline,
        unitsMode: unitsMode,
        selectedUnitIds: selectedUnitIds,
        showProgress: showProgress,
        showSplit: showSplit,
        variant: variant,
        units: units,
        balanceByUnit: balanceByUnit,
      );

  // ---- Original #29 coverage (unchanged behaviour) ----

  test('with a daily limit: amount left, currency, progress', () {
    final s = build(spent: 50000, limit: dayLimit);
    expect(s.amount, '1,500');
    expect(s.currency, 'KSh');
    expect(s.caption, 'left today');
    expect(s.progress, closeTo(0.25, 1e-9));
    expect(s.status, 'safe');
  });

  test('over the limit: says how far over, and clamps the bar', () {
    final s = build(spent: 250000, limit: dayLimit);
    expect(s.amount, '500');
    expect(s.caption, 'over today');
    expect(s.progress, 1.0);
    expect(s.status, 'overdraft');
  });

  test('exactly at the limit: nothing left', () {
    final s = build(spent: 200000, limit: dayLimit);
    expect(s.amount, '0');
    expect(s.caption, 'nothing left');
    expect(s.progress, 1.0);
  });

  test('no limit set: shows what was spent, no bar', () {
    final s = build(spent: 12345);
    expect(s.amount, '123.45');
    expect(s.caption, 'spent today');
    expect(s.progress, isNull);
  });

  test('trailing .00 is trimmed, real cents are not', () {
    expect(build(spent: 0, limit: dayLimit).amount, '2,000');
    expect(build(spent: 12345).amount, '123.45');
  });

  test('toJson has no nulls and uses -1.0 for "no bar"', () {
    final withBar = build(spent: 50000, limit: dayLimit).toJson();
    final withoutBar = build(spent: 100).toJson();
    expect(withBar.values, isNot(contains(null)));
    expect(withoutBar['progress'], -1.0);
  });

  // ---- #113 coverage: the new options ----

  test('headline: spent today and total I have', () {
    expect(
      build(spent: 12345, limit: dayLimit,
          headline: BannerHeadline.spentToday).caption,
      'spent today',
    );

    final t = build(
      spent: 0,
      headline: BannerHeadline.totalIHave,
      units: [
        mockUnit('cash', 'Cash', 76000),
        mockUnit('mpesa', 'Mobile', 345000),
      ],
      balanceByUnit: const {'cash': 76000, 'mpesa': 345000},
    );
    expect(t.caption, 'in total');
    expect(t.amount, '4,210');
  });

  test('showProgress off drops the bar even when a limit exists', () {
    expect(
      build(spent: 50000, limit: dayLimit, showProgress: false).progress,
      isNull,
    );
  });

  test('split line lists the units it was asked for', () {
    final t = build(
      spent: 0,
      units: [
        mockUnit('cash', 'Cash', 76000),
        mockUnit('mpesa', 'Mobile', 345000),
      ],
      balanceByUnit: const {'cash': 76000, 'mpesa': 345000},
      showSplit: true,
    );
    expect(t.splitLine, 'Cash 760.00 · Mobile 3,450.00');
  });

  test('split line respects the mode and the switch', () {
    final u = [
      mockUnit('cash', 'Cash', 76000),
      mockUnit('mpesa', 'Mobile', 345000),
    ];
    final b = {'cash': 76000, 'mpesa': 345000};

    // selected, only cash
    final selected = build(
      spent: 0,
      units: u,
      balanceByUnit: b,
      unitsMode: BannerUnitsMode.selected,
      selectedUnitIds: const {'cash'},
      showSplit: true,
    );
    expect(selected.splitLine, 'Cash 760.00');

    // none
    final none = build(
      spent: 0,
      units: u,
      balanceByUnit: b,
      unitsMode: BannerUnitsMode.none,
      showSplit: true,
    );
    expect(none.splitLine, isEmpty);

    // switch off
    final off = build(
      spent: 0,
      units: u,
      balanceByUnit: b,
      showSplit: false,
    );
    expect(off.splitLine, isEmpty);
  });

  test('toJson carries the split line and the variant', () {
    final m = build(spent: 100).toJson();
    expect(m['splitLine'], '');
    expect(m['variant'], 'auto');
  });
}