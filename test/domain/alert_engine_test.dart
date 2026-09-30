import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/alert_engine.dart';
import 'package:fuata/domain/models/limit_alert.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  // Wednesday 30 Sep 2026, midday. Week starts Mon 28th; month is 2026-09.
  final now = DateTime(2026, 9, 30, 12);

  MoneyUnit unit(String id, {bool archived = false}) => MoneyUnit(
    id: id,
    name: id,
    kind: UnitKind.cash,
    currencyCode: 'KES',
    iconEmoji: '💵',
    color: const Color(0xFF000000),
    openingBalanceMinor: 0,
    sortOrder: 0,
    createdAt: now,
    archived: archived,
  );

  MoneyTransaction spend(String unitId, int minor, {DateTime? at, String? id}) =>
      MoneyTransaction(
        id: id ?? 't${minor}_$unitId',
        unitId: unitId,
        type: TxType.spent,
        amountMinor: -minor,
        occurredAt: at ?? now,
        createdAt: at ?? now,
      );

  LimitRule limit({
    String id = 'l_day',
    LimitScope scope = LimitScope.overall,
    String? unitId,
    LimitPeriod period = LimitPeriod.day,
    int amount = 100000, // 1,000.00
    double warn = 0.7,
    double danger = 0.9,
    bool enabled = true,
  }) => LimitRule(
    id: id,
    scope: scope,
    unitId: unitId,
    period: period,
    amountMinor: amount,
    currencyCode: 'KES',
    warnAt: warn,
    dangerAt: danger,
    enabled: enabled,
  );

  List<LimitAlert> due(
      List<LimitRule> limits,
      List<MoneyTransaction> txs, {
        Set<AlertKey> fired = const {},
        List<MoneyUnit>? units,
      }) => AlertEngine.due(
    limits: limits,
    units: units ?? [unit('cash'), unit('mpesa')],
    transactions: txs,
    fired: fired,
    now: now,
  );

  group('levels', () {
    test('nothing below the first threshold', () {
      expect(due([limit()], [spend('cash', 69999)]), isEmpty);
    });

    test('warning at warnAt, danger at dangerAt, overdraft at 100%', () {
      expect(due([limit()], [spend('cash', 70000)]).single.level,
          AlertLevel.warning);
      expect(due([limit()], [spend('cash', 90000)]).single.level,
          AlertLevel.danger);
      expect(due([limit()], [spend('cash', 100000)]).single.level,
          AlertLevel.overdraft);
      expect(due([limit()], [spend('cash', 150000)]).single.level,
          AlertLevel.overdraft);
    });

    test('follows the limit\'s own levels, not fixed 70/90', () {
      final l = limit(warn: 0.5, danger: 0.6);
      expect(due([l], [spend('cash', 50000)]).single.level, AlertLevel.warning);
      expect(due([l], [spend('cash', 60000)]).single.level, AlertLevel.danger);
    });

    test('levelFor agrees with LimitRule.statusFor at every boundary', () {
      final l = limit();
      for (final spent in [0, 69999, 70000, 89999, 90000, 99999, 100000]) {
        final status = l.statusFor(spent);
        final level = AlertEngine.levelFor(l, spent);
        expect(level?.status ?? SpendStatus.safe, status, reason: '$spent');
      }
    });
  });

  group('once per threshold per period', () {
    test('an already-fired level is not due again', () {
      final fired = {const AlertKey('l_day', '2026-09-30', AlertLevel.warning)};
      expect(due([limit()], [spend('cash', 75000)], fired: fired), isEmpty);
    });

    test('crossing the next level is due even after the lower one fired', () {
      final fired = {const AlertKey('l_day', '2026-09-30', AlertLevel.warning)};
      final a = due([limit()], [spend('cash', 95000)], fired: fired).single;
      expect(a.level, AlertLevel.danger);
    });

    test('a jump straight to over is one alert that uses up the levels below',
            () {
          final a = due([limit()], [spend('cash', 120000)]).single;
          expect(a.level, AlertLevel.overdraft);
          expect(a.consumedKeys.map((k) => k.level), [
            AlertLevel.warning,
            AlertLevel.danger,
            AlertLevel.overdraft,
          ]);
        });

    test('yesterday\'s firing does not silence today', () {
      final fired = {const AlertKey('l_day', '2026-09-29', AlertLevel.warning)};
      expect(due([limit()], [spend('cash', 75000)], fired: fired), hasLength(1));
    });

    test('yesterday\'s spending does not count toward today', () {
      final yesterday = DateTime(2026, 9, 29, 20);
      expect(due([limit()], [spend('cash', 95000, at: yesterday)]), isEmpty);
    });
  });

  group('period keys', () {
    test('day is the date', () {
      expect(AlertEngine.periodKey(LimitPeriod.day, now), '2026-09-30');
    });

    test('week is the Monday it started', () {
      expect(AlertEngine.periodKey(LimitPeriod.week, now), '2026-09-28');
      // Sunday still belongs to the same Monday-start week.
      expect(AlertEngine.periodKey(LimitPeriod.week, DateTime(2026, 10, 4)),
          '2026-09-28');
      expect(AlertEngine.periodKey(LimitPeriod.week, DateTime(2026, 10, 5)),
          '2026-10-05');
    });

    test('month is year-month, including across a year boundary', () {
      expect(AlertEngine.periodKey(LimitPeriod.month, now), '2026-09');
      expect(AlertEngine.periodKey(LimitPeriod.month, DateTime(2027, 1, 3)),
          '2027-01');
    });
  });

  group('which limits count', () {
    test('a disabled limit never alerts', () {
      expect(due([limit(enabled: false)], [spend('cash', 200000)]), isEmpty);
    });

    test('a zero or negative amount never alerts', () {
      expect(due([limit(amount: 0)], [spend('cash', 1)]), isEmpty);
    });

    test('moved and got transactions are not spending', () {
      final moved = MoneyTransaction(
        id: 'm',
        unitId: 'cash',
        type: TxType.moved,
        amountMinor: -95000,
        occurredAt: now,
        createdAt: now,
      );
      final got = MoneyTransaction(
        id: 'g',
        unitId: 'cash',
        type: TxType.got,
        amountMinor: 95000,
        occurredAt: now,
        createdAt: now,
      );
      expect(due([limit()], [moved, got]), isEmpty);
    });

    test('an overall limit counts every unit', () {
      final a = due([limit()], [spend('cash', 40000), spend('mpesa', 40000)]);
      expect(a.single.level, AlertLevel.warning);
      expect(a.single.unitName, isNull);
    });

    test('an overall limit ignores spending in another currency', () {
      final usd = MoneyUnit(
        id: 'usd',
        name: 'Dollars',
        kind: UnitKind.cash,
        currencyCode: 'USD',
        iconEmoji: '💵',
        color: const Color(0xFF000000),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: now,
      );
      final txs = [spend('usd', 95000), spend('cash', 10000)];
      // 950 in USD must not count toward the 1,000 KES limit.
      expect(due([limit()], txs, units: [unit('cash'), usd]), isEmpty);
    });

    test('an overall limit still counts an archived unit\'s spending', () {
      // `units` is the active list, so an archived unit is simply absent.
      expect(due([limit()], [spend('gone', 80000)], units: [unit('cash')]),
          hasLength(1));
    });

    test('a per-unit limit counts only that unit and names it', () {
      final l = limit(
        id: 'l_unit_mpesa_day',
        scope: LimitScope.unit,
        unitId: 'mpesa',
      );
      // Lots of cash spending, little on mpesa: no alert.
      expect(due([l], [spend('cash', 90000), spend('mpesa', 10000)]), isEmpty);
      final a = due([l], [spend('mpesa', 80000)]).single;
      expect(a.level, AlertLevel.warning);
      expect(a.unitName, 'mpesa');
    });

    test('a per-unit limit on an archived or missing unit is skipped', () {
      final l = limit(
        id: 'l_unit_old_day',
        scope: LimitScope.unit,
        unitId: 'old',
      );
      final txs = [spend('old', 99000)];
      expect(due([l], txs, units: [unit('old', archived: true)]), isEmpty);
      expect(due([l], txs, units: [unit('cash')]), isEmpty);
    });

    test('several limits alert independently', () {
      final day = limit();
      final month = limit(id: 'l_month', period: LimitPeriod.month, amount: 200000);
      final alerts = due([day, month], [spend('cash', 95000)]);
      // 950 of a 1,000 day (danger), but only 47.5% of the 2,000 month.
      expect(alerts.map((a) => a.limit.id), ['l_day']);
      expect(alerts.single.level, AlertLevel.danger);
    });
  });

  group('quiet hours', () {
    bool inside(int start, int end, int h, [int m = 0]) => QuietHours.contains(
      startMinute: start,
      endMinute: end,
      at: DateTime(2026, 9, 30, h, m),
    );

    test('a same-day window includes its start and excludes its end', () {
      expect(inside(13 * 60, 15 * 60, 13), isTrue);
      expect(inside(13 * 60, 15 * 60, 14, 59), isTrue);
      expect(inside(13 * 60, 15 * 60, 15), isFalse);
      expect(inside(13 * 60, 15 * 60, 12, 59), isFalse);
    });

    test('a window that wraps midnight covers both sides of it', () {
      const start = 22 * 60, end = 7 * 60;
      expect(inside(start, end, 23), isTrue);
      expect(inside(start, end, 0), isTrue);
      expect(inside(start, end, 6, 59), isTrue);
      expect(inside(start, end, 7), isFalse);
      expect(inside(start, end, 12), isFalse);
      expect(inside(start, end, 21, 59), isFalse);
    });

    test('an empty window is never quiet', () {
      expect(inside(8 * 60, 8 * 60, 8), isFalse);
      expect(inside(0, 0, 3), isFalse);
    });
  });

  group('alert text', () {
    LimitAlert alert(AlertLevel level, int spent,
        {String? unitName, LimitPeriod period = LimitPeriod.day}) =>
        LimitAlert(
          limit: limit(period: period),
          level: level,
          periodKey: 'k',
          spentMinor: spent,
          unitName: unitName,
        );

    test('warning reads like the brief\'s example', () {
      final t = AlertText.build(alert(AlertLevel.warning, 80000));
      expect(t.title, '🟡 Easy now');
      expect(t.body, "You've used 80% of today's limit.");
    });

    test('names the unit and the period', () {
      final t = AlertText.build(
        alert(AlertLevel.danger, 92000, unitName: 'Mobile', period: LimitPeriod.week),
      );
      expect(t.title, '🟠 Almost at your limit');
      expect(t.body, "You've used 92% of this week's limit on Mobile.");
    });

    test('over says by how much', () {
      final t = AlertText.build(alert(AlertLevel.overdraft, 120000));
      expect(t.title, "🔴 You're over");
      expect(t.body, startsWith("You're over today's limit by "));
      expect(t.body, contains('200'));
    });
  });
}
