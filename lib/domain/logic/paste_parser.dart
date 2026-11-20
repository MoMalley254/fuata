// ---------------------------------------------------------------------------
// The paste path's parser, shared by the add-transaction sheet's Paste button
// and the home-screen widget's Paste button (issue #153). One function, so the
// two can never read the same message differently.
//
// Pure: callers hand in the units and each unit's templates. No providers,
// no platform — that's what lets the widget's second Flutter engine use it.
// ---------------------------------------------------------------------------

import '../models/parsed_paste.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../models/unit.dart';
import 'parser.dart';

enum PasteFailure {
  /// No money units yet — there is nowhere to record anything.
  noUnits,

  /// Units exist but none has a reading rule, so nothing can be matched.
  noTemplates,

  /// Rules exist; none of them matched this message.
  unreadable;

  String get message => switch (this) {
        PasteFailure.noUnits =>
          'Create money units first, then paste a message.',
        PasteFailure.noTemplates =>
          "Fuata doesn't know any message formats yet. Teach it one first.",
        PasteFailure.unreadable =>
          "Couldn't read this message. Try teaching Fuata this format first.",
      };
}

class PasteParseResult {
  const PasteParseResult.success(ParsedPaste p) : parsed = p, failure = null;
  const PasteParseResult.failure(PasteFailure f) : parsed = null, failure = f;

  final ParsedPaste? parsed;
  final PasteFailure? failure;
}

class PasteParser {
  PasteParser._();

  static PasteParseResult parse(
    String text, {
    required List<MoneyUnit> units,
    required Map<String, List<CaptureTemplate>> templatesByUnit,
  }) {
    if (units.isEmpty) {
      return const PasteParseResult.failure(PasteFailure.noUnits);
    }

    var anyTemplates = false;
    for (final unit in units) {
      final templates = templatesByUnit[unit.id] ?? const <CaptureTemplate>[];
      if (templates.isEmpty) continue;
      anyTemplates = true;

      final result = Parser.parse(
        text,
        templates,
        currencyCode: unit.currencyCode,
      );
      final fields = result.fields;
      if (result.matched && fields != null && fields.amountMinor != null) {
        return PasteParseResult.success(
          ParsedPaste(
            rawText: text,
            amountMinor: fields.amountMinor!,
            type: result.type ?? TxType.spent,
            counterparty: fields.counterparty,
            occurredAt: fields.occurredAt,
            code: fields.code,
            feeMinor: fields.feeMinor,
            balanceAfterMinor: fields.balanceAfterMinor,
            unitId: unit.id,
            currencyCode: unit.currencyCode,
          ),
        );
      }
    }

    return PasteParseResult.failure(
      anyTemplates ? PasteFailure.unreadable : PasteFailure.noTemplates,
    );
  }
}
