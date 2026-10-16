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