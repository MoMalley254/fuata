// ---------------------------------------------------------------------------
// The words on a capture notification (the one that says "I caught this —
// Accept, Fix or Discard?"). Pure functions: no plugin, no clock, no I/O, so
// the wording and the privacy masking are unit-testable
// (test/domain/capture_notification_content_test.dart).
//
// It mirrors PendingCard in the review inbox on purpose: the same line a
// person would read in the app is the line they read here.
//
// Nothing in here logs amounts.
// ---------------------------------------------------------------------------
import 'package:intl/intl.dart';

import '../models/money.dart';
import '../models/transaction.dart';
import '../models/unit.dart';

class CaptureNotificationContent {
  final String transactionId;
  final String title;
  final String body;
  const CaptureNotificationContent({
    required this.transactionId,
    required this.title,
    required this.body,
  });
}

class CaptureNotificationText {
  CaptureNotificationText._();

  /// [fees] are the capture's child rows (ADR-005); they are folded into the
  /// title as "+ 5.00 fee", exactly as PendingCard does. [amountsHidden] is
  /// the person's "hide amounts" switch — a notification is somewhere money
  /// could be seen, so it honours it.
  static CaptureNotificationContent build({
    required MoneyTransaction transaction,
    required List<MoneyTransaction> fees,
    required MoneyUnit? unit,
    required bool amountsHidden,
    required String currencyCode,
  }) {
    final currency = unit?.currencyCode ?? currencyCode;
    String money(int minor) => amountsHidden
        ? kHiddenAmountMask
        : '$currency ${Money(minor.abs(), currency).format()}';

    final isInflow = transaction.amountMinor >= 0;
    final feeMinor = fees.fold<int>(0, (sum, x) => sum + x.amountMinor.abs());
    final feeText = feeMinor > 0 ? ' + ${money(feeMinor)} fee' : '';
    final title =
        '${isInflow ? '💰 Got' : '💸 Spent'} ${money(transaction.amountMinor)}$feeText';

    final who = transaction.counterparty;
    final unitName = unit?.name;
    final when = DateFormat('d MMM, h:mm a').format(transaction.occurredAt);

    final lines = <String>[
      [
        if (who != null && who.isNotEmpty) who,
        if (unitName != null && unitName.isNotEmpty) unitName,
      ].join(' · '),
      [
        when,
        if (transaction.code != null && transaction.code!.isNotEmpty)
          'Code ${transaction.code}',
      ].join(' · '),
      if (transaction.balanceAfterMinor != null)
        'Balance in the message: ${money(transaction.balanceAfterMinor!)}',
    ].where((l) => l.isNotEmpty).toList();

    return CaptureNotificationContent(
      transactionId: transaction.id,
      title: title,
      body: lines.join('\n'),
    );
  }

  /// Posted after Accept from the notification when the balance the message
  /// quoted disagrees with the ledger — the in-app version is the snackbar
  /// with its "Update balance" button.
  static CaptureNotificationContent balanceMismatch({
    required String transactionId,
    required MoneyUnit unit,
    required int quotedMinor,
    required int ledgerMinor,
    required bool amountsHidden,
  }) {
    String money(int minor) => amountsHidden
        ? kHiddenAmountMask
        : '${unit.currencyCode} ${Money(minor, unit.currencyCode).format()}';
    return CaptureNotificationContent(
      transactionId: transactionId,
      title: 'Added — but the balance looks off',
      body:
          'The message says ${money(quotedMinor)}, but the ledger says '
          '${money(ledgerMinor)} for ${unit.name}.',
    );
  }
}
