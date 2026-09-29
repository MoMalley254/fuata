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
        selected: {'cash'}, headline: BannerHeadline.totalIHave);
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
}
