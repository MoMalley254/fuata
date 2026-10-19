import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/outings_alert_engine.dart';
import 'package:fuata/domain/models/limit_alert.dart';
import 'package:fuata/domain/models/outing.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);

  MoneyUnit unit(String id, {String currency = 'KES'}) => MoneyUnit(
    id: id,
    name: id,
    kind: UnitKind.cash,
    currencyCode: currency,
    iconEmoji: '💵',
    color: const Color(0xFF000000),
    openingBalanceMinor: 0,
    sortOrder: 0,
    createdAt: now,
  );

  Outing outing({int amount = 100000}) => Outing(
    id: 'o1',
    name: 'Trip',
    amountMinor: amount,
    currencyCode: 'KES',
    startAt: DateTime(2026, 10, 15),
    endAt: DateTime(2026, 10, 20),
    createdAt: now,
  );

  MoneyTransaction spend(String unitId, int minor) => MoneyTransaction(
    id: 't$minor',
    unitId: unitId,
    type: TxType.spent,
    amountMinor: -minor,
    occurredAt: now,
    createdAt: now,
  );

  test('no alert under the warning threshold', () {
    final alerts = OutingAlertEngine.due(
      outings: [outing()],
      units: [unit('u1')],
      transactions: [spend('u1', 60000)],
      fired: const {},
      now: now,
    );
    expect(alerts, isEmpty);
  });

  test('warning at 70, danger at 90, overdraft at 100', () {
    for (final (spent, level) in [
      (70000, AlertLevel.warning),
      (90000, AlertLevel.danger),
      (100000, AlertLevel.overdraft),
    ]) {
      final alerts = OutingAlertEngine.due(
        outings: [outing()],
        units: [unit('u1')],
        transactions: [spend('u1', spent)],
        fired: const {},
        now: now,
      );
      expect(alerts.single.level, level);
    }
  });

  test('an already-fired alert is not returned again', () {
    final fired = {
      const AlertKey('o1', 'outing', AlertLevel.warning),
    };
    final alerts = OutingAlertEngine.due(
      outings: [outing()],
      units: [unit('u1')],
      transactions: [spend('u1', 70000)],
      fired: fired,
      now: now,
    );
    expect(alerts, isEmpty);
  });

  test('an inactive outing does not alert', () {
    final past = outing().copyWith(
      startAt: DateTime(2026, 9, 1),
      endAt: DateTime(2026, 9, 5),
    );
    final alerts = OutingAlertEngine.due(
      outings: [past],
      units: [unit('u1')],
      transactions: [spend('u1', 200000)],
      fired: const {},
      now: now,
    );
    expect(alerts, isEmpty);
  });

  test('the alert carries a trip-specific period label', () {
    final alerts = OutingAlertEngine.due(
      outings: [outing()],
      units: [unit('u1')],
      transactions: [spend('u1', 70000)],
      fired: const {},
      now: now,
    );
    expect(alerts.single.periodLabel, "this trip's");
  });
}