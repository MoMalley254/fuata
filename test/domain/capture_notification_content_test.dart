// What a caught-payment notification says, and what it must not say when the
// person has hidden their amounts. Pure Dart: no plugin, no database.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/capture_notification_content.dart';
import 'package:fuata/domain/models/money.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  final at = DateTime(2026, 9, 21, 13, 12);

  final unit = MoneyUnit(
    id: 'u_mm',
    name: 'Mobile money',
    kind: UnitKind.mobileMoney,
    currencyCode: 'KES',
    iconEmoji: '📱',
    color: const Color(0xFF3D7FE0),
    openingBalanceMinor: 0,
    sortOrder: 0,
    createdAt: DateTime(2026, 9, 1),
  );

  MoneyTransaction tx({
    int amountMinor = -35000,
    String? counterparty = 'JAVA HOUSE',
    String? code = 'QW12ABC3',
    int? balanceAfterMinor = 124500,
  }) => MoneyTransaction(
    id: 'cap_1',
    unitId: 'u_mm',
    type: amountMinor < 0 ? TxType.spent : TxType.got,
    amountMinor: amountMinor,
    counterparty: counterparty,
    code: code,
    occurredAt: at,
    createdAt: at,
    source: TxSource.notification,
    status: TxStatus.pending,
    balanceAfterMinor: balanceAfterMinor,
  );

  MoneyTransaction fee(int minor) => MoneyTransaction(
    id: 'cap_1_fee',
    unitId: 'u_mm',
    type: TxType.spent,
    amountMinor: -minor,
    counterparty: 'Fee',
    occurredAt: at,
    createdAt: at,
    parentId: 'cap_1',
    status: TxStatus.pending,
  );

  CaptureNotificationContent build(
    MoneyTransaction t, {
    List<MoneyTransaction> fees = const [],
    MoneyUnit? u,
    bool hidden = false,
  }) => CaptureNotificationText.build(
    transaction: t,
    fees: fees,
    unit: u ?? unit,
    amountsHidden: hidden,
    currencyCode: 'KES',
  );

  test('a spend shows what, how much, who, where, when and the code', () {
    final c = build(tx());

    expect(c.transactionId, 'cap_1');
    expect(c.title, contains('Spent'));
    expect(c.title, contains('KES'));
    expect(c.title, contains('350'));
    expect(c.body, contains('JAVA HOUSE'));
    expect(c.body, contains('Mobile money'));
    expect(c.body, contains('21 Sep'));
    expect(c.body, contains('Code QW12ABC3'));
    expect(c.body, contains('1,245'));
  });

  test('money in reads as Got', () {
    final c = build(tx(amountMinor: 120000, counterparty: 'ALICE'));
    expect(c.title, contains('Got'));
    expect(c.title, isNot(contains('Spent')));
  });

  test('a fee is folded into the title, as the inbox card does', () {
    final c = build(tx(), fees: [fee(500)]);
    expect(c.title, contains('fee'));
    expect(c.title, contains('5.00'));
  });

  test('missing details leave no empty lines or dangling separators', () {
    final c = build(tx(counterparty: null, code: null, balanceAfterMinor: null));

    expect(c.body.split('\n').every((l) => l.trim().isNotEmpty), isTrue);
    expect(c.body, isNot(contains('Code')));
    expect(c.body, isNot(contains('Balance')));
    expect(c.body.contains(' · \n'), isFalse);
  });

  test('hidden amounts are masked everywhere money would appear', () {
    final c = build(tx(), fees: [fee(500)], hidden: true);

    expect(c.title, contains(kHiddenAmountMask));
    expect(c.body, contains(kHiddenAmountMask));
    for (final digits in ['350', '5.00', '1,245']) {
      expect(c.title, isNot(contains(digits)));
      expect(c.body, isNot(contains(digits)));
    }
  });

  test('a capture whose unit has gone still produces a readable notification', () {
    final c = CaptureNotificationText.build(
      transaction: tx(),
      fees: const [],
      unit: null,
      amountsHidden: false,
      currencyCode: 'KES',
    );
    expect(c.title, contains('350'));
    expect(c.body, contains('JAVA HOUSE'));
  });

  test('the balance mismatch follow-up names both numbers, or masks them', () {
    final shown = CaptureNotificationText.balanceMismatch(
      transactionId: 'cap_1',
      unit: unit,
      quotedMinor: 70000,
      ledgerMinor: 65000,
      amountsHidden: false,
    );
    expect(shown.body, contains('700'));
    expect(shown.body, contains('650'));
    expect(shown.body, contains('Mobile money'));

    final masked = CaptureNotificationText.balanceMismatch(
      transactionId: 'cap_1',
      unit: unit,
      quotedMinor: 70000,
      ledgerMinor: 65000,
      amountsHidden: true,
    );
    expect(masked.body, contains(kHiddenAmountMask));
    expect(masked.body, isNot(contains('700')));
  });
}
