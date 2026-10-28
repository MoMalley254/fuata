import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/ledger.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/money.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  final now = DateTime(2026, 9, 22, 10, 0);

  MoneyUnit unit({int opening = 0}) => MoneyUnit(
    id: 'u1',
    name: 'Cash',
    kind: UnitKind.cash,
    currencyCode: 'KES',
    iconEmoji: '💵',
    color: const Color(0xFF000000),
    openingBalanceMinor: opening,
    sortOrder: 0,
    createdAt: now,
  );

  MoneyTransaction tx({
    required int amountMinor,
    TxType type = TxType.spent,
    TxStatus status = TxStatus.confirmed,
    DateTime? occurredAt,
    String? transferGroupId,
  }) =>
      MoneyTransaction(
        id: 't${amountMinor}_${occurredAt ?? now}',
        unitId: 'u1',
        type: type,
        amountMinor: amountMinor,
        occurredAt: occurredAt ?? now,
        createdAt: now,
        status: status,
        transferGroupId: transferGroupId,
      );

  group('Money', () {
    test('M-01 parses "1,250.50" to minor units', () {
      expect(Money.parseMajor('1,250.50', 'KES').minor, 125050);
    });

    test('M-04 sums 0.10 + 0.20 exactly', () {
      final a = Money.parseMajor('0.10', 'KES');
      final b = Money.parseMajor('0.20', 'KES');
      expect((a + b).minor, 30);
    });
  });

  group('Ledger.balanceOf', () {
    test('L-01 balance equals opening when no transactions', () {
      expect(Ledger.balanceOf(unit(opening: 1000), []), 1000);
    });

    test('L-02/L-03 spent decreases, got increases balance', () {
      final u = unit(opening: 1000);
      final all = [tx(amountMinor: -350, type: TxType.spent), tx(amountMinor: 500, type: TxType.got)];
      expect(Ledger.balanceOf(u, all), 1150);
    });

    test('L-04 transfer nets to zero across both unit balances', () {
      final a = unit(opening: 1000).copyWith();
      final txOut = tx(amountMinor: -200, type: TxType.moved, transferGroupId: 'g1');
      expect(Ledger.balanceOf(a, [txOut]), 800);
      // The paired +200 row on the other unit is symmetric by construction.
    });

    test('L-07 pending transaction excluded from balance', () {
      final u = unit(opening: 1000);
      final all = [tx(amountMinor: -300, status: TxStatus.pending)];
      expect(Ledger.balanceOf(u, all), 1000);
    });
  });

  group('Ledger.spentInPeriod', () {
    test('excludes moved rows from spending total', () {
      final all = [
        tx(amountMinor: -300, type: TxType.spent),
        tx(amountMinor: -200, type: TxType.moved, transferGroupId: 'g1'),
      ];
      final (start, end) = Ledger.todayRange(now);
      expect(Ledger.spentInPeriod(all, start, end), 300);
    });
  });

  group('LimitRule.statusFor thresholds', () {
    final limit = const LimitRule(
      id: 'l1',
      scope: LimitScope.overall,
      period: LimitPeriod.day,
      amountMinor: 100000,
      currencyCode: 'KES',
    );

    test('T-01 ratio 0.69 -> safe', () {
      expect(limit.statusFor(69000), SpendStatus.safe);
    });
    test('T-02 ratio 0.70 -> warning', () {
      expect(limit.statusFor(70000), SpendStatus.warning);
    });
    test('T-04 ratio 0.90 -> danger', () {
      expect(limit.statusFor(90000), SpendStatus.danger);
    });
    test('T-06 ratio 1.00 -> overdraft', () {
      expect(limit.statusFor(100000), SpendStatus.overdraft);
    });
  });

  // Issue #108. The range helpers must (a) read the *local* calendar day even
  // when handed a UTC `now`, and (b) build their end with calendar arithmetic,
  // not a fixed 24h/168h offset. The assertions are written to hold in any
  // runner timezone; the UTC and DST cases only bite where the zone makes them
  // bite, so also run:
  //   TZ=Africa/Nairobi flutter test test/domain/ledger_test.dart
  //   TZ=America/New_York flutter test test/domain/ledger_test.dart
  //   TZ=Pacific/Auckland flutter test test/domain/ledger_test.dart
  group('Ledger ranges (#108)', () {
    int spentIn((DateTime, DateTime) r, List<MoneyTransaction> all) =>
        Ledger.spentInPeriod(all, r.$1, r.$2);

    test('R-01: a UTC now gives the same ranges as its local equivalent', () {
      // 23:00 UTC on the 14th is 02:00 on the 15th in EAT.
      final utc = DateTime.utc(2026, 10, 14, 23, 0);
      expect(Ledger.todayRange(utc), Ledger.todayRange(utc.toLocal()));
      expect(Ledger.weekRange(utc), Ledger.weekRange(utc.toLocal()));
      expect(Ledger.monthRange(utc), Ledger.monthRange(utc.toLocal()));
    });

    test('R-02: todayRange starts at the local midnight of the local day', () {
      final utc = DateTime.utc(2026, 10, 14, 23, 0);
      final local = utc.toLocal();
      final (start, end) = Ledger.todayRange(utc);
      expect(start, DateTime(local.year, local.month, local.day));
      expect(end, DateTime(local.year, local.month, local.day + 1));
      expect(start.isUtc, isFalse);
    });

    test('R-03: yesterday evening does not count against today', () {
      final at = DateTime(2026, 10, 15, 9, 0);
      final all = [
        tx(amountMinor: -111, occurredAt: DateTime(2026, 10, 14, 23, 59)),
        tx(amountMinor: -222, occurredAt: DateTime(2026, 10, 15, 0, 0)),
        tx(amountMinor: -333, occurredAt: DateTime(2026, 10, 15, 23, 59)),
        tx(amountMinor: -444, occurredAt: DateTime(2026, 10, 16, 0, 0)),
      ];
      expect(spentIn(Ledger.todayRange(at), all), 222 + 333);
    });

    test('R-04: the same holds when now and occurredAt are both UTC', () {
      // Build the instants from local wall-clock times, then hand them over
      // as UTC — the shape a backup import or the parser produces. 02:00
      // local is still the previous day in UTC for any zone east of it, which
      // is exactly where the old code picked the wrong day.
      final nowUtc = DateTime(2026, 10, 15, 2, 0).toUtc();
      final all = [
        tx(
          amountMinor: -111,
          occurredAt: DateTime(2026, 10, 14, 23, 59).toUtc(),
        ),
        tx(
          amountMinor: -222,
          occurredAt: DateTime(2026, 10, 15, 0, 0).toUtc(),
        ),
        tx(
          amountMinor: -333,
          occurredAt: DateTime(2026, 10, 16, 0, 0).toUtc(),
        ),
      ];
      expect(spentIn(Ledger.todayRange(nowUtc), all), 222);
    });

    test('R-05: weekRange is Monday-start; Sunday night stays in its week', () {
      // 2026-10-25 is a Sunday, 2026-10-26 a Monday.
      final sunday = DateTime(2026, 10, 25, 23, 30);
      final (s1, e1) = Ledger.weekRange(sunday);
      expect(s1, DateTime(2026, 10, 19));
      expect(e1, DateTime(2026, 10, 26));

      final monday = DateTime(2026, 10, 26, 0, 0);
      final (s2, e2) = Ledger.weekRange(monday);
      expect(s2, DateTime(2026, 10, 26));
      expect(e2, DateTime(2026, 11, 2));

      final all = [
        tx(amountMinor: -100, occurredAt: DateTime(2026, 10, 25, 23, 59)),
        tx(amountMinor: -200, occurredAt: DateTime(2026, 10, 26, 0, 0)),
      ];
      expect(spentIn((s1, e1), all), 100);
      expect(spentIn((s2, e2), all), 200);
    });

    test('R-06: a UTC now near a week boundary picks the local week', () {
      // 22:00 UTC on Sunday the 25th is 01:00 Monday the 26th in EAT.
      final utc = DateTime.utc(2026, 10, 25, 22, 0);
      final local = utc.toLocal();
      final (start, end) = Ledger.weekRange(utc);
      expect(start.weekday, DateTime.monday);
      expect(start.isAfter(local), isFalse);
      expect(end.isAfter(local), isTrue);
      expect(end.difference(start).inHours, inInclusiveRange(167, 169));
    });

    test('R-07: monthRange rolls over the year and is local-first', () {
      final (s, e) = Ledger.monthRange(DateTime(2026, 12, 5, 12, 0));
      expect(s, DateTime(2026, 12, 1));
      expect(e, DateTime(2027, 1, 1));

      // 22:00 UTC on 31 Oct is already 1 Nov in EAT.
      final utc = DateTime.utc(2026, 10, 31, 22, 0);
      expect(Ledger.monthRange(utc), Ledger.monthRange(utc.toLocal()));
    });

    test('R-08: month edges are half-open on local midnight', () {
      final at = DateTime(2026, 10, 15, 9, 0);
      final all = [
        tx(amountMinor: -100, occurredAt: DateTime(2026, 9, 30, 23, 59)),
        tx(amountMinor: -200, occurredAt: DateTime(2026, 10, 1, 0, 0)),
        tx(amountMinor: -300, occurredAt: DateTime(2026, 10, 31, 23, 59)),
        tx(amountMinor: -400, occurredAt: DateTime(2026, 11, 1, 0, 0)),
      ];
      expect(spentIn(Ledger.monthRange(at), all), 200 + 300);
    });

    // DST cases. They pass trivially in a zone without DST (Nairobi, UTC) and
    // fail on the old `start + Duration(...)` code under TZ=America/New_York.
    test('R-09: a 25-hour day (US fall-back) keeps its last hour', () {
      final at = DateTime(2026, 11, 1, 12, 0);
      final all = [tx(amountMinor: -500, occurredAt: DateTime(2026, 11, 1, 23, 30))];
      expect(spentIn(Ledger.todayRange(at), all), 500);
      expect(Ledger.todayRange(at).$2, DateTime(2026, 11, 2));
    });

    test('R-10: a 23-hour day (US spring-forward) does not leak into the next', () {
      final at = DateTime(2026, 3, 8, 12, 0);
      final all = [tx(amountMinor: -500, occurredAt: DateTime(2026, 3, 9, 0, 30))];
      expect(spentIn(Ledger.todayRange(at), all), 0);
      expect(Ledger.todayRange(at).$2, DateTime(2026, 3, 9));
    });

    test('R-11: weeks containing a DST change still end on Monday 00:00', () {
      // Fall-back week: Mon 26 Oct – Sun 1 Nov 2026.
      final fall = Ledger.weekRange(DateTime(2026, 10, 28, 12, 0));
      expect(fall.$2, DateTime(2026, 11, 2));
      expect(
        spentIn(fall, [
          tx(amountMinor: -700, occurredAt: DateTime(2026, 11, 1, 23, 30)),
        ]),
        700,
      );

      // Spring-forward week: Mon 2 Mar – Sun 8 Mar 2026.
      final spring = Ledger.weekRange(DateTime(2026, 3, 4, 12, 0));
      expect(spring.$2, DateTime(2026, 3, 9));
      expect(
        spentIn(spring, [
          tx(amountMinor: -700, occurredAt: DateTime(2026, 3, 9, 0, 30)),
        ]),
        0,
      );
    });
  });

  group('Ledger.spentByDay (#82)', () {
    test('S-20: seven days, oldest first, today last', () {
      final at = DateTime(2026, 9, 30, 15, 0); // Wed
      final all = [
        tx(amountMinor: -10000, occurredAt: DateTime(2026, 9, 28, 9, 0)),
        tx(amountMinor: -25000, occurredAt: DateTime(2026, 9, 29, 9, 0)),
        tx(amountMinor: -5000, occurredAt: DateTime(2026, 9, 30, 9, 0)),
        // A week before the window: outside it.
        tx(amountMinor: -99999, occurredAt: DateTime(2026, 9, 23, 9, 0)),
        // Same day as the -25000, counted in.
        tx(amountMinor: -7000, occurredAt: DateTime(2026, 9, 29, 23, 0)),
      ];
      expect(
        Ledger.spentByDay(all, now: at),
        [0, 0, 0, 0, 10000, 32000, 5000],
      );
    });

    test('S-21: moved, adjustment and pending rows are all excluded', () {
      final at = DateTime(2026, 9, 30, 15, 0);
      final all = [
        tx(amountMinor: -3000, occurredAt: DateTime(2026, 9, 30, 9, 0)),
        tx(
          amountMinor: -5000,
          type: TxType.moved,
          transferGroupId: 'g1',
          occurredAt: DateTime(2026, 9, 30, 10, 0),
        ),
        tx(
          amountMinor: -2000,
          type: TxType.adjustment,
          occurredAt: DateTime(2026, 9, 30, 11, 0),
        ),
        tx(
          amountMinor: -1000,
          status: TxStatus.pending,
          occurredAt: DateTime(2026, 9, 30, 12, 0),
        ),
      ];
      expect(Ledger.spentByDay(all, now: at).last, 3000);
    });

    test('S-22: a custom window length', () {
      final at = DateTime(2026, 9, 30, 15, 0);
      final all = [
        tx(amountMinor: -100, occurredAt: DateTime(2026, 9, 30, 9, 0)),
        tx(amountMinor: -200, occurredAt: DateTime(2026, 9, 29, 9, 0)),
        tx(amountMinor: -300, occurredAt: DateTime(2026, 9, 28, 9, 0)),
        tx(amountMinor: -400, occurredAt: DateTime(2026, 9, 27, 9, 0)),
      ];
      expect(Ledger.spentByDay(all, now: at, days: 3), [300, 200, 100]);
    });

    test('S-23: 23:59 and 00:00 land on their own days', () {
      final at = DateTime(2026, 9, 30, 15, 0);
      final all = [
        tx(amountMinor: -100, occurredAt: DateTime(2026, 9, 29, 23, 59)),
        tx(amountMinor: -200, occurredAt: DateTime(2026, 9, 30, 0, 0)),
      ];
      final out = Ledger.spentByDay(all, now: at);
      expect(out[5], 100); // yesterday
      expect(out[6], 200); // today
    });

    test('S-24: a UTC occurredAt is bucketed by its local calendar day (#109)',
            () {
          // A UTC instant. In EAT (UTC+3) local is 02:00 on the 15th; in
          // UTC it's 23:00 on the 14th. The bucket must follow the *local*
          // calendar day — i.e. match `utc.toLocal()`'s year/month/day,
          // never the UTC ones.
          final utc = DateTime.utc(2026, 10, 14, 23, 0);
          final local = utc.toLocal();
          final localDay = DateTime(local.year, local.month, local.day);

          // Anchor `now` at local noon on the 15th so both the 14th and
          // the 15th fall inside the seven-day window whatever the
          // runner's timezone happens to be (UTC-12 to UTC+14).
          final now = DateTime(2026, 10, 15, 12, 0);
          final today = DateTime(now.year, now.month, now.day);
          final start = today.subtract(const Duration(days: 6));
          final index = localDay.difference(start).inDays;
          expect(
            index,
            inInclusiveRange(0, 6),
            reason: 'precondition: the instant falls inside the window',
          );

          final out = Ledger.spentByDay(
            [tx(amountMinor: -5000, occurredAt: utc)],
            now: now,
          );
          expect(out[index], 5000);
          // The UTC calendar day is the 14th; if the fix were missing the
          // amount would land there in every zone east of UTC. Asserting
          // on the UTC day would be wrong on a UTC runner, so the check
          // above is the portable one. This line just makes the intent
          // explicit for a UTC+3 dev machine.
        });
  });
}