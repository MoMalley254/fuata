import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/banner_content.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  final now = DateTime(2026, 9, 29);

  MoneyUnit unit(String id, String name, {bool archived = false}) => MoneyUnit(
        id: id,
        name: name,
        kind: UnitKind.cash,
        currencyCode: 'KES',
        iconEmoji: '💵',
        color: const Color(0xFF000000),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: now,
        archived: archived,
      );

  final limit = const LimitRule(
    id: 'l1',
    scope: LimitScope.overall,
    period: LimitPeriod.day,
    amountMinor: 300000, // 3,000.00
    currencyCode: 'KES',
  );
  final cash = unit('cash', 'Cash');
  final mpesa = unit('mpesa', 'Mobile');

  BannerContent build({
    int spent = 150000,
    LimitRule? dailyLimit,
    BannerHeadline headline = BannerHeadline.leftToday,
    BannerUnitsMode mode = BannerUnitsMode.all,
    Set<String> selected = const {},
    bool progress = true,
    bool redacted = false,
    List<MoneyUnit>? units,
  }) {
    final l = dailyLimit ?? limit;
    return BannerContent.build(
      status: l.statusFor(spent),
      spentToday: spent,
      dailyLimit: l,
      units: units ?? [cash, mpesa],
      balanceByUnit: {'cash': 76000, 'mpesa': 345000},
      headline: headline,
      unitsMode: mode,
      selectedUnitIds: selected,
      showProgress: progress,
      showQuickAdd: true,
      redacted: redacted,
    );
  }

  test('left today: emoji, amount left, progress', () {
    final b = build();
    expect(b.title, '🟢 1,500.00 left today');
    expect(b.progress, closeTo(0.5, 1e-9));
  });

  test('overdraft says how far over', () {
    final b = build(spent: 320000);
    expect(b.status, SpendStatus.overdraft);
    expect(b.title, '🔴 Over by 200.00');
    expect(b.progress, 1.0); // clamped
  });

  test('spent today and total headlines', () {
    expect(build(headline: BannerHeadline.spentToday).title,
        '🟢 Spent 1,500.00 today');
    expect(build(headline: BannerHeadline.totalIHave).title,
        '🟢 4,210.00 in total');
  });

  test('picked units limit the split and the total', () {
    final b = build(
        mode: BannerUnitsMode.selected,
        selected: {'cash'},
        headline: BannerHeadline.totalIHave);
    expect(b.unitLines, ['Cash 760.00']);
    expect(b.title, '🟢 760.00 in total');
  });

  test('archived units never appear', () {
    final b = build(units: [cash, unit('old', 'Old', archived: true)]);
    expect(b.unitLines, ['Cash 760.00']);
  });

  test('progress hidden when switched off', () {
    expect(build(progress: false).progress, isNull);
  });

  test('redacted (lock screen) shows no amounts at all', () {
    final b = build(redacted: true);
    expect(b.title, "🟢 You're good");
    expect(b.unitLines, isEmpty);
    expect(b.spentLine, isNull);
  });

  group('BannerUnitsMode (#86)', () {
    test('all lists every active unit and totals them', () {
      final b = build(
          mode: BannerUnitsMode.all, headline: BannerHeadline.totalIHave);
      expect(b.unitLines, ['Cash 760.00', 'Mobile 3,450.00']);
      expect(b.title, '🟢 4,210.00 in total');
    });

    test('none drops the unit lines but not the total', () {
      final b = build(
          mode: BannerUnitsMode.none, headline: BannerHeadline.totalIHave);
      expect(b.unitLines, isEmpty);
      // The person asked for no split, not for their total to read zero.
      expect(b.title, '🟢 4,210.00 in total');
    });

    test('none leaves the spent-today line and the left-today headline intact',
            () {
          final b = build(mode: BannerUnitsMode.none);
          expect(b.unitLines, isEmpty);
          expect(b.spentLine, 'Spent today 1,500.00');
          expect(b.title, '🟢 1,500.00 left today');
        });

    test('selected ignores an empty id set the way "all" used to', () {
      // Regression guard: the old "empty means all" trick is gone.
      final b = build(mode: BannerUnitsMode.selected, selected: const {});
      expect(b.unitLines, isEmpty);
    });

    test('archived units are excluded in every mode', () {
      final withOld = [cash, unit('old', 'Old', archived: true)];
      for (final m in BannerUnitsMode.values) {
        expect(
          build(mode: m, units: withOld).unitLines,
          isNot(contains('Old 0.00')),
          reason: '$m',
        );
      }
    });
  });
}
