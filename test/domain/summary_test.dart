import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/ledger.dart';
import 'package:fuata/domain/logic/summary.dart';
import 'package:fuata/domain/models/transaction.dart';

void main() {
  // Wednesday 30 Sep 2026, 15:00. Week = Mon 28 Sep to Mon 5 Oct.
  final now = DateTime(2026, 9, 30, 15, 0);

  MoneyTransaction tx(
    String id,
    int amountMinor, {
    TxType type = TxType.spent,
    String unitId = 'u1',
    String? who,
    DateTime? at,
    TxStatus status = TxStatus.confirmed,
    String? parentId,
  }) => MoneyTransaction(
    id: id,
    unitId: unitId,
    type: type,
    amountMinor: amountMinor,
    counterparty: who,
    occurredAt: at ?? DateTime(2026, 9, 30, 9, 0),
    createdAt: now,
    status: status,
    parentId: parentId,
  );

  PeriodSummary day(List<MoneyTransaction> all) =>
      PeriodSummary.build(all, SummaryPeriod.day, now);

  group('totals (US-12)', () {
    test('S-01 spent and got ignore moved, adjustments and pending', () {
      final s = day([
        tx('a', -30000, who: 'Java House'),
        tx('b', -20000, who: 'java house '),
        tx('c', 100000, type: TxType.got, who: 'Salary'),
        tx('d', -5000, type: TxType.moved),
        tx('e', -9999, status: TxStatus.pending),
        tx('f', 700, type: TxType.adjustment),
      ]);
      expect(s.spentMinor, 50000);
      expect(s.gotMinor, 100000);
      expect(s.transactionCount, 3);
    });

    test('S-02 spent matches Ledger.spentInPeriod for the same range', () {
      final all = [
        tx('a', -30000),
        tx('b', -12345, at: DateTime(2026, 9, 29, 20, 0)),
        tx('c', -777, at: DateTime(2026, 9, 1, 8, 0)),
      ];
      for (final p in SummaryPeriod.values) {
        final s = PeriodSummary.build(all, p, now);
        expect(s.spentMinor, Ledger.spentInPeriod(all, s.from, s.to));
      }
    });

    test('S-03 week starts Monday 00:00; Sunday night is last week', () {
      final s = PeriodSummary.build([
        tx('sun', -100, at: DateTime(2026, 9, 27, 23, 59)),
        tx('mon', -200, at: DateTime(2026, 9, 28, 0, 0)),
        tx('nextMon', -400, at: DateTime(2026, 10, 5, 0, 0)),
      ], SummaryPeriod.week, now);
      expect(s.spentMinor, 200);
    });

    test('S-04 month is the calendar month', () {
      final s = PeriodSummary.build([
        tx('aug', -100, at: DateTime(2026, 8, 31, 23, 59)),
        tx('sep1', -200, at: DateTime(2026, 9, 1, 0, 0)),
        tx('oct', -400, at: DateTime(2026, 10, 1, 0, 0)),
      ], SummaryPeriod.month, now);
      expect(s.spentMinor, 200);
    });

    test('S-05 include filter drops transactions from the total', () {
      final s = PeriodSummary.build(
        [tx('a', -300), tx('b', -700, unitId: 'usd')],
        SummaryPeriod.day,
        now,
        include: (t) => t.unitId != 'usd',
      );
      expect(s.spentMinor, 300);
    });
  });

  group('top recipients and per-unit split', () {
    test('S-06 recipients group ignoring case and rank by amount', () {
      final s = day([
        tx('a', -30000, who: 'Java House'),
        tx('b', -20000, who: 'java house '),
        tx('c', -60000, who: 'Naivas'),
        tx('d', -100),
      ]);
      expect(s.spentTo.map((r) => r.label), ['Naivas', 'Java House']);
      expect(s.spentTo[1].minor, 50000);
      expect(s.spentTo[1].count, 2);
      expect(s.unnamedSpentMinor, 100);
      expect(s.spentMinor, 110100);
    });

    test('S-07 a fee counts toward its parent payment, not as its own', () {
      final s = day([
        tx('pay', -10000, who: 'Naivas'),
        tx('fee', -500, parentId: 'pay'),
      ]);
      expect(s.spentTo.length, 1);
      expect(s.spentTo.first.label, 'Naivas');
      expect(s.spentTo.first.minor, 10500);
      expect(s.spentTo.first.count, 1);
      expect(s.spentMinor, 10500);
      expect(s.transactionCount, 1);
    });

    test('S-08 money received is ranked by who it came from', () {
      final s = day([
        tx('a', 5000, type: TxType.got, who: 'Mum'),
        tx('b', 9000, type: TxType.got, who: 'Salary'),
      ]);
      expect(s.gotFrom.map((r) => r.label), ['Salary', 'Mum']);
    });

    test('S-09 spending splits by unit, biggest first', () {
      final s = day([
        tx('a', -300, unitId: 'cash'),
        tx('b', -700, unitId: 'mpesa'),
        tx('c', -100, unitId: 'cash'),
      ]);
      expect(s.spentByUnit.map((u) => u.unitId), ['mpesa', 'cash']);
      expect(s.spentByUnit.map((u) => u.minor), [700, 400]);
    });
  });

  group('previous period and story', () {
    test('S-10 previous day is cut at the same time of day', () {
      final s = day([
        tx('y1', -4000, at: DateTime(2026, 9, 29, 10, 0)),
        tx('y2', -9000, at: DateTime(2026, 9, 29, 18, 0)), // after 15:00
        tx('t', -4400),
      ]);
      expect(s.previousSpentMinor, 4000);
    });

    test('S-11 previous week is cut at the same point in the week', () {
      final s = PeriodSummary.build([
        tx('in', -100, at: DateTime(2026, 9, 22, 9, 0)),
        tx('late', -900, at: DateTime(2026, 9, 26, 9, 0)), // Sat, too far in
      ], SummaryPeriod.week, now);
      expect(s.previousSpentMinor, 100);
    });

    test('S-12 previous month crosses a year boundary', () {
      final jan = DateTime(2027, 1, 10, 12, 0);
      final s = PeriodSummary.build([
        tx('dec', -500, at: DateTime(2026, 12, 5, 9, 0)),
      ], SummaryPeriod.month, jan);
      expect(s.previousSpentMinor, 500);
    });

    test('S-13 story names the total, the top spot and the comparison', () {
      final s = day([
        tx('y', -4000, at: DateTime(2026, 9, 29, 10, 0)),
        tx('t', -842000, who: 'Java House'),
      ]);
      expect(
        s.story('KES'),
        'Today you spent KSh 8,420. Java House was your top spot. '
        'Quite a bit more than yesterday.',
      );
    });

    test('S-14 comparison wording follows the size of the change', () {
      String said(int today, int yesterday) => day([
        tx('y', -yesterday, at: DateTime(2026, 9, 29, 10, 0)),
        tx('t', -today),
      ]).story('KES');

      expect(said(4400, 4000), endsWith('A bit more than yesterday.'));
      expect(said(4000, 4000), endsWith('About the same as yesterday.'));
      expect(said(3700, 4000), endsWith('A bit less than yesterday.'));
      expect(said(2000, 4000), endsWith('Quite a bit less than yesterday.'));
    });

    test('S-15 nothing to compare with means no comparison sentence', () {
      final s = day([tx('t', -5000, who: 'Naivas')]);
      expect(s.story('KES'), 'Today you spent KSh 50. Naivas was your top spot.');
    });

    test('S-16 empty period says so, without alarm', () {
      final s = day([]);
      expect(s.hasActivity, isFalse);
      expect(s.story('KES'), 'Nothing recorded today yet.');
    });

    test('S-17 income only says nothing was spent', () {
      final s = day([tx('a', 5000, type: TxType.got, who: 'Mum')]);
      expect(
        s.story('KES'),
        "You haven't spent anything today, and KSh 50 came in.",
      );
    });

    test('S-18 average per day counts today, and is 1 day on a Monday', () {
      final wed = PeriodSummary.build([tx('a', -3000)], SummaryPeriod.week, now);
      expect(wed.daysSoFar, 3); // Mon, Tue, Wed
      expect(wed.averageSpentPerDayMinor, 1000);

      final mon = PeriodSummary.build(
        [tx('a', -3000, at: DateTime(2026, 9, 28, 8, 0))],
        SummaryPeriod.week,
        DateTime(2026, 9, 28, 12, 0),
      );
      expect(mon.daysSoFar, 1);
    });

    test('S-19 friendlyMoney drops .00 but keeps real cents', () {
      expect(friendlyMoney(842000, 'KES'), 'KSh 8,420');
      expect(friendlyMoney(842050, 'KES'), 'KSh 8,420.50');
    });
  });
}
