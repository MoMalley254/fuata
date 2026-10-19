import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/outings.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/outing.dart';
import 'package:fuata/domain/models/transaction.dart';

void main() {
  // Fri 17 Oct 2026, 10:00.
  final now = DateTime(2026, 10, 17, 10);

  Outing outing({
    String id = 'o1',
    DateTime? startAt,
    DateTime? endAt,
    Set<String> unitIds = const {},
    bool enabled = true,
    String currency = 'KES',
    int amount = 1500000,  // 15,000.00
    DateTime? createdAt,
  }) => Outing(
    id: id,
    name: 'Mombasa trip',
    amountMinor: amount,
    currencyCode: currency,
    startAt: startAt ?? DateTime(2026, 10, 15),
    endAt: endAt ?? DateTime(2026, 10, 20),
    unitIds: unitIds,
    enabled: enabled,
    createdAt: createdAt ?? DateTime(2026, 10, 1),
  );

  MoneyTransaction spend({
    required int minor,
    required String unitId,
    DateTime? at,
  }) => MoneyTransaction(
    id: 't_${minor}_$unitId',
    unitId: unitId,
    type: TxType.spent,
    amountMinor: -minor,
    occurredAt: at ?? DateTime(2026, 10, 16),
    createdAt: DateTime(2026, 10, 16),
  );

  group('isActive', () {
    test('inside the window', () {
      expect(outing().isActive(now), isTrue);
    });
    test('before the window', () {
      final o = outing(startAt: DateTime(2026, 10, 20));
      expect(o.isActive(now), isFalse);
      expect(o.isUpcoming, isTrue);
    });
    test('after the window', () {
      final o = outing(endAt: DateTime(2026, 10, 15));
      expect(o.isActive(now), isFalse);
      expect(o.isPast, isTrue);
    });
    test('at the start, inclusive', () {
      expect(outing(startAt: now).isActive(now), isTrue);
    });
    test('at the end, exclusive', () {
      expect(outing(endAt: now).isActive(now), isFalse);
    });
    test('disabled is never active', () {
      expect(outing(enabled: false).isActive(now), isFalse);
    });
  });

  group('activeFrom', () {
    test('returns the most recently created active outing', () {
      final older = outing(id: 'old', createdAt: DateTime(2026, 9, 1));
      final newer = outing(id: 'new', createdAt: DateTime(2026, 10, 1));
      expect(
        Outings.activeFrom([older, newer], now: now)?.id,
        'new',
      );
    });
    test('returns null when none are active', () {
      final o = outing(startAt: DateTime(2027, 1, 1));
      expect(Outings.activeFrom([o], now: now), isNull);
    });
  });

  group('spentIn', () {
    final currencyByUnit = {'cash': 'KES', 'mpesa': 'KES', 'usd': 'USD'};
    final txs = [
      spend(minor: 10000, unitId: 'cash'),
      spend(minor: 20000, unitId: 'mpesa'),
      spend(minor: 30000, unitId: 'usd'),   // USD — excluded
      spend(
        minor: 40000,
        unitId: 'cash',
        at: DateTime(2026, 10, 14),  // before the window
      ),
      spend(
        minor: 50000,
        unitId: 'cash',
        at: DateTime(2026, 10, 21),  // after the window
      ),
    ];

    test('all units: sums all in-window, in-currency spending', () {
      expect(
        Outings.spentIn(outing(), txs, currencyByUnit: currencyByUnit),
        30000,  // 10000 + 20000
      );
    });

    test('only selected units', () {
      expect(
        Outings.spentIn(
          outing(unitIds: {'mpesa'}),
          txs,
          currencyByUnit: currencyByUnit,
        ),
        20000,
      );
    });

    test('excludes transactions outside the window', () {
      // The 40000 and 50000 outside the window are already excluded by
      // the previous test; this checks the shape works when the outing
      // is narrower.
      expect(
        Outings.spentIn(
          outing(startAt: DateTime(2026, 10, 16), endAt: DateTime(2026, 10, 17)),
          [spend(minor: 8000, unitId: 'cash', at: DateTime(2026, 10, 16))],
          currencyByUnit: currencyByUnit,
        ),
        8000,
      );
    });
  });

  group('statusFor', () {
    test('safe/warning/danger/overdraft at 70/90/100', () {
      final o = outing(amount: 100000);
      expect(Outings.statusFor(o, 69999), SpendStatus.safe);
      expect(Outings.statusFor(o, 70000), SpendStatus.warning);
      expect(Outings.statusFor(o, 90000), SpendStatus.danger);
      expect(Outings.statusFor(o, 100000), SpendStatus.overdraft);
      expect(Outings.statusFor(o, 150000), SpendStatus.overdraft);
    });
    test('a status equals the same rule as the limit engine', () {
      final o = outing(amount: 100000);
      final l = o.asLimit();
      for (final s in [0, 50000, 75000, 95000, 100000, 200000]) {
        expect(Outings.statusFor(o, s), l.statusFor(s));
      }
    });
  });

  group('dayCount', () {
    test('3 days for a Fri-Sun trip', () {
      final o = outing(
        startAt: DateTime(2026, 10, 16, 15),
        endAt: DateTime(2026, 10, 19, 11),
      );
      expect(o.dayCount, 3);
    });
    test('1 day for a single evening', () {
      final o = outing(
        startAt: DateTime(2026, 10, 16, 19),
        endAt: DateTime(2026, 10, 17, 1),
      );
      expect(o.dayCount, 1);
    });
  });
}