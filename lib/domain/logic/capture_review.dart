// ---------------------------------------------------------------------------
// Dealing with a pending capture: "Looks right" and "Not mine".
//
// This used to live inside PendingCard (the review inbox's card). The
// capture notification's Accept / Discard buttons (see
// platform/capture_notification_actions.dart) run in a *background isolate*
// with no widgets and no Riverpod, so the logic moved here: it depends only
// on repository interfaces, which means the inbox card and the notification
// buttons run literally the same code and cannot drift apart.
// ---------------------------------------------------------------------------
import '../models/transaction.dart';
import '../models/unit.dart';
import '../repositories/repositories.dart';
import 'ledger.dart';

/// What [CaptureReview.accept] did.
class AcceptResult {
  /// False when there was nothing pending under that id — already accepted,
  /// discarded or fixed-and-accepted somewhere else. Not an error: both the
  /// notification and the inbox can be acted on twice.
  final bool found;

  /// The unit the capture belongs to, when it still exists.
  final MoneyUnit? unit;

  /// The balance the original message quoted, if it quoted one.
  final int? quotedBalanceMinor;

  /// What the ledger says the unit holds now this row is in.
  final int? ledgerBalanceMinor;

  const AcceptResult._({
    required this.found,
    this.unit,
    this.quotedBalanceMinor,
    this.ledgerBalanceMinor,
  });

  const AcceptResult.notFound() : this._(found: false);

  const AcceptResult.accepted({
    MoneyUnit? unit,
    int? quotedBalanceMinor,
    int? ledgerBalanceMinor,
  }) : this._(
         found: true,
         unit: unit,
         quotedBalanceMinor: quotedBalanceMinor,
         ledgerBalanceMinor: ledgerBalanceMinor,
       );

  /// Reconcile (requirements.md section 5): the message quoted a balance
  /// and the ledger now disagrees with it.
  bool get balanceMismatch =>
      found &&
      unit != null &&
      quotedBalanceMinor != null &&
      ledgerBalanceMinor != null &&
      quotedBalanceMinor != ledgerBalanceMinor;
}

class CaptureReview {
  CaptureReview({
    required TransactionRepository transactions,
    required UnitRepository units,
  }) : _transactions = transactions,
       _units = units;

  final TransactionRepository _transactions;
  final UnitRepository _units;

  /// "Looks right": confirms the capture and its fee row, then reconciles
  /// against the balance the message quoted.
  Future<AcceptResult> accept(String transactionId) async {
    final all = await _transactions.watchTransactions().first;
    final t = _pending(all, transactionId);
    if (t == null) return const AcceptResult.notFound();

    final children = all.where((x) => x.parentId == t.id).toList();

    await _transactions.confirmTransaction(t.id);
    for (final child in children) {
      await _transactions.confirmTransaction(child.id);
    }

    final units = await _units.watchUnits().first;
    final unit = units.where((u) => u.id == t.unitId).firstOrNull;
    final quoted = t.balanceAfterMinor;
    if (unit == null || quoted == null) {
      return AcceptResult.accepted(unit: unit, quotedBalanceMinor: quoted);
    }

    // Everything that was already confirmed, plus this row and its fee.
    final others = all.where(
      (x) => x.isConfirmed && x.id != t.id && x.parentId != t.id,
    );
    final computed =
        Ledger.balanceOf(unit, others) +
        t.amountMinor +
        children.fold<int>(0, (sum, x) => sum + x.amountMinor);

    return AcceptResult.accepted(
      unit: unit,
      quotedBalanceMinor: quoted,
      ledgerBalanceMinor: computed,
    );
  }

  /// "Not mine": removes the capture and its fee row. Returns false when
  /// there was nothing pending under that id.
  Future<bool> discard(String transactionId) async {
    final all = await _transactions.watchTransactions().first;
    final t = _pending(all, transactionId);
    if (t == null) return false;

    for (final child in all.where((x) => x.parentId == t.id)) {
      await _transactions.deleteTransaction(child.id);
    }
    await _transactions.deleteTransaction(t.id);
    return true;
  }

  /// Sets (or clears, with null) the category of a pending capture.
  ///
  /// Writes to the very same row the inbox card and the Fix sheet edit, from
  /// a fresh read, so the three can't drift apart. Returns false when
  /// there is no pending row under that id.
  Future<bool> setCategory(String transactionId, String? categoryId) async {
    final all = await _transactions.watchTransactions().first;
    final t = _pending(all, transactionId);
    if (t == null) return false;
    await _transactions.updateTransaction(t.copyWith(categoryId: categoryId));
    return true;
  }

  /// Sets the note of a pending capture; blank clears it (the inbox card
  /// stores a blank note as null too). Same row, same rules as
  /// [setCategory]. Returns false when there is no pending row.
  Future<bool> setNote(String transactionId, String? note) async {
    final all = await _transactions.watchTransactions().first;
    final t = _pending(all, transactionId);
    if (t == null) return false;
    final trimmed = note?.trim();
    await _transactions.updateTransaction(
      t.copyWith(note: (trimmed == null || trimmed.isEmpty) ? null : trimmed),
    );
    return true;
  }

  /// Only a *pending* row can be accepted or discarded from a capture
  /// notification. A confirmed row with the same id means the person
  /// already accepted it in the app, and a stale Discard button must never
  /// delete money they have already confirmed.
  MoneyTransaction? _pending(List<MoneyTransaction> all, String id) {
    for (final t in all) {
      if (t.id == id && !t.isConfirmed) return t;
    }
    return null;
  }
}
