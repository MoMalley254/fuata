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

import '../models/category.dart';
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

/// Which set of buttons a capture notification shows. Android shows at most
/// three actions, so the extra jobs (note, category) live one step behind
/// "Add details" rather than being crammed onto the first row.
enum CaptureNotificationMode {
  /// Accept · Add details · Discard.
  main,

  /// Note (inline reply) · Category · Fix.
  details,

  /// The person's most-used categories, one button each.
  categories,
}

class CaptureNotificationText {
  CaptureNotificationText._();

  /// How many category buttons fit on one notification (Android's limit on
  /// actions).
  static const maxCategoryButtons = 3;

  /// The categories to offer as buttons: the ones used most on confirmed
  /// transactions, ties (and a fresh install with no history) falling back
  /// to the person's own category order. Archived ones are never offered.
  static List<Category> topCategories({
    required List<Category> categories,
    required List<MoneyTransaction> transactions,
    int limit = maxCategoryButtons,
  }) {
    final uses = <String, int>{};
    for (final t in transactions) {
      final id = t.categoryId;
      if (id != null && t.isConfirmed) uses[id] = (uses[id] ?? 0) + 1;
    }
    final active = categories.where((c) => !c.archived).toList()
      ..sort((a, b) {
        final byUse = (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0);
        return byUse != 0 ? byUse : a.sortOrder.compareTo(b.sortOrder);
      });
    return active.take(limit).toList();
  }

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
    Category? category,
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
      if (category != null) 'Category: ${category.emoji} ${category.name}',
      if (transaction.note != null && transaction.note!.trim().isNotEmpty)
        'Note: ${transaction.note!.trim()}',
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
