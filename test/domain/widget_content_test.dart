// Issue #29: the home-screen widget's snapshot. Pure Dart — the actual
// RemoteViews rendering is verified on device (#26), not here.

import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/widget_content.dart';
import 'package:fuata/domain/models/limit_rule.dart';

void main() {
  final dayLimit = LimitRule(
    id: 'l_overall_day',
    scope: LimitScope.overall,
    period: LimitPeriod.day,
    amountMinor: 200000, // 2,000.00
    currencyCode: 'KES',
  );

  WidgetSnapshot build({
    required int spent,
    LimitRule? limit,
    String currency = 'KES',
  }) =>
      WidgetSnapshot.build(
        status: limit == null
            ? SpendStatus.safe
            : limit.statusFor(spent),
        spentToday: spent,
        dailyLimit: limit,
        currencyCode: currency,
      );

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
}