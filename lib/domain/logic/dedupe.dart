import 'package:fuata/data/constants/captures_constants.dart';

import '../models/transaction.dart';

/// Dedupe rule from requirements.md section 5: "by transaction code when
/// present; otherwise unit + amount + 2-minute window" — testing.md
/// P-07 (same code seen twice -> one row) and P-08 (the same payment
/// arriving as both an SMS and a push notification, no code -> one row).
///
/// Pure function over already-loaded transactions so it is unit-testable
/// without a database; the capture service (#21) loads the list and
/// calls this before inserting a captured transaction. This is where
/// parser_test.dart's deferred P-07/P-08 cases actually live.
class Dedupe {
  const Dedupe._();

  static const defaultWindow = dedupeWindowDuration;

/// [at] is when the money moved (the parsed date, or now if the
/// message carried none). [amountMinor] is the SIGNED effect on the
/// balance, matching how rows are stored (ADR-004).
 static bool isDuplicate(List<MoneyTransaction> existing, {
   required String unitId,
   required int amountMinor,
   required DateTime at,
   String? code,
   Duration window = defaultWindow,
 }) {
   final trimmedCode = code?.trim();
   if (trimmedCode != null && trimmedCode.isNotEmpty) {
     // P-07: the code is provider-unique, so any row in this unit with
     // the same code is the same payment — regardless of amount or
     // when it says it happened.
     return existing.any(
           (t) => t.unitId == unitId && t.code == trimmedCode,
     );
   }

   // P-08: no code -> same unit, same signed amount, inside the window.
   return existing.any(
         (t) =>
     t.unitId == unitId &&
         t.amountMinor == amountMinor &&
         t.occurredAt.difference(at).abs() <= window,
   );
 }
}