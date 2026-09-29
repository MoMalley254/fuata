import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/dedupe.dart';
import 'package:fuata/domain/models/transaction.dart';

void main() {
  // testing.md P-07/P-08: the parser tests defer these two cases to
  // where dedupe actually runs — the capture path (#21). Fake codes and
  // amounts only; no real provider wording.

  final now = DateTime(2026, 9, 27, 10, 0);

  MoneyTransaction tx({
    required String id,
    String unitId = 'u_mm',
    int amountMinor = -35000,
    DateTime? occurredAt,
    String? code,
  }) => MoneyTransaction(
    id: id,
    unitId: unitId,
    type: amountMinor >= 0 ? TxType.got : TxType.spent,
    amountMinor: amountMinor,
    code: code,
    occurredAt: occurredAt ?? now,
    createdAt: now,
  );

  group('P-07 dedupe by transaction code', () {
    final stored = [tx(id: 't1', code: 'QW12ABC3', amountMinor: -35000)];

    test('same code on the same unit is a duplicate, even with different amount/time', () {
      // A re-sent notification can carry a different quoted amount or
      // time; the code is what makes it the same payment.
      expect(
        Dedupe.isDuplicate(
          stored,
          unitId: 'u_mm',
          amountMinor: -35000,
          at: now.add(const Duration(minutes: 40)),
          code: 'QW12ABC3',
        ),
        isTrue,
      );
    });

    test('same code on a different unit is not a duplicate', () {
      expect(
        Dedupe.isDuplicate(
          stored,
          unitId: 'u_cash',
          amountMinor: -35000,
          at: now,
          code: 'QW12ABC3',
        ),
        isFalse,
      );
    });

    test('a different code is not a duplicate', () {
      expect(
        Dedupe.isDuplicate(
          stored,
          unitId: 'u_mm',
          amountMinor: -35000,
          at: now,
          code: 'ZZ99XYZ1',
        ),
        isFalse,
      );
    });
  });

  group('P-08 dedupe by unit + amount + 2-minute window when no code', () {
    final stored = [tx(id: 't1', amountMinor: -35000, occurredAt: now)];

    test(
      'same unit and amount within 2 minutes is a duplicate (SMS + push)',
      () {
        expect(
          Dedupe.isDuplicate(
            stored,
            unitId: 'u_mm',
            amountMinor: -35000,
            at: now.add(const Duration(minutes: 1)),
          ),
          isTrue,
        );
      },
    );

    test('just outside the 2-minute window is not a duplicate', () {
      expect(
        Dedupe.isDuplicate(
          stored,
          unitId: 'u_mm',
          amountMinor: -35000,
          at: now.add(const Duration(minutes: 3)),
        ),
        isFalse,
      );
    });

    test('same time but a different amount is not a duplicate', () {
      expect(
        Dedupe.isDuplicate(stored, unitId: 'u_mm', amountMinor: -3500, at: now),
        isFalse,
      );
    });

    test('the opposite direction of the same money is not a duplicate', () {
      expect(
        Dedupe.isDuplicate(stored, unitId: 'u_mm', amountMinor: 35000, at: now),
        isFalse,
      );
    });
  });
}
