import 'package:intl/intl.dart';

import '../models/money.dart';
import '../models/template.dart';
import '../models/transaction.dart';

/// The typed fields recovered from a message, in the vocabulary
/// requirements.md US-08 asks the rule builder to let the user label:
/// amount, code, date, person, balance, fee. All-optional because not
/// every template labels every field (e.g. a template with no fee).
class ParsedFields {
  final int? amountMinor;
  final int? feeMinor;
  final int? balanceAfterMinor;
  final String? code;
  final DateTime? occurredAt;
  final String? counterparty;

  const ParsedFields({
    this.amountMinor,
    this.feeMinor,
    this.balanceAfterMinor,
    this.code,
    this.occurredAt,
    this.counterparty,
  });

  @override
  String toString() =>
      'ParsedFields(amount: $amountMinor, fee: $feeMinor, balanceAfter: $balanceAfterMinor, '
      'code: $code, occurredAt: $occurredAt, counterparty: $counterparty)';
}

/// The outcome of `Parser.parse`. A non-match (testing.md P-05) is a
/// normal, expected result — callers route it to the "couldn't read this"
/// list (design.md's capture flow), not an error.
class ParseResult {
  final CaptureTemplate? template;
  final TxType? type;
  final ParsedFields? fields;

  const ParseResult._({this.template, this.type, this.fields});

  const ParseResult.noMatch() : this._();

  const ParseResult.matched({
    required CaptureTemplate template,
    required TxType type,
    required ParsedFields fields,
  }) : this._(template: template, type: type, fields: fields);

  bool get matched => template != null;
}

/// Pure functions only — no Flutter, no I/O (design.md section 1) — so
/// this is unit-testable against fake messages without a device
/// (testing.md's Parser plan, P-01 to P-12). Dedupe against already-stored
/// transactions needs repository access and is out of scope here; it's
/// built alongside the review inbox and listener (#21/#22).
class Parser {
  const Parser._();

  /// Tries each enabled template in order (a unit can have several — one
  /// per message shape, testing.md P-06) and returns the first match.
  /// [currencyCode] is the unit's currency, used to turn a captured amount
  /// string into minor units via [Money.parseMajor].
  static ParseResult parse(
    String message,
    List<CaptureTemplate> templates, {
    required String currencyCode,
  }) {
    for (final template in templates.where((t) => t.enabled)) {
      final match = template.compiled.firstMatch(message);
      if (match == null) continue;

      int? amountMinor;
      int? feeMinor;
      int? balanceAfterMinor;
      String? code;
      DateTime? occurredAt;
      String? counterparty;

      for (final entry in template.fieldMap.entries) {
        final raw = match.namedGroup(entry.key);
        if (raw == null) continue;
        switch (entry.value) {
          case TemplateFieldType.amount:
            amountMinor = _parseAmountMinor(raw, currencyCode);
            break;
          case TemplateFieldType.fee:
            feeMinor = _parseAmountMinor(raw, currencyCode);
            break;
          case TemplateFieldType.balance:
            balanceAfterMinor = _parseAmountMinor(raw, currencyCode);
            break;
          case TemplateFieldType.code:
            code = raw.trim();
            break;
          case TemplateFieldType.date:
            occurredAt = _parseDate(raw.trim());
            break;
          case TemplateFieldType.person:
            counterparty = raw.trim();
            break;
        }
      }

      // A match with no amount isn't a usable transaction — keep trying
      // other templates rather than returning a half-parsed result.
      if (amountMinor == null) continue;

      return ParseResult.matched(
        template: template,
        type: _resolveType(template.direction, message),
        fields: ParsedFields(
          amountMinor: amountMinor,
          feeMinor: feeMinor,
          balanceAfterMinor: balanceAfterMinor,
          code: code,
          occurredAt: occurredAt,
          counterparty: counterparty,
        ),
      );
    }
    return const ParseResult.noMatch();
  }

  static TxType _resolveType(TemplateDirection direction, String message) {
    switch (direction) {
      case TemplateDirection.spent:
        return TxType.spent;
      case TemplateDirection.got:
        return TxType.got;
      case TemplateDirection.either:
        final lower = message.toLowerCase();
        const gotWords = ['received', 'credited', 'deposit'];
        return gotWords.any(lower.contains) ? TxType.got : TxType.spent;
    }
  }

  /// Strips an optional currency-letter prefix ("Ksh", "KES ") the amount
  /// field pattern allows, then reuses `Money.parseMajor` for the actual
  /// minor-unit math (ADR-003: integer minor units, no floats).
  static int _parseAmountMinor(String raw, String currencyCode) {
    final stripped = raw
        .replaceFirst(RegExp(r'^[A-Za-z]{2,5}\.?\s*'), '')
        .trim();
    return Money.parseMajor(stripped, currencyCode).minor;
  }

  /// testing.md P-09: "21/9/26 at 1:12 PM" and ISO both need to parse to
  /// the correct timestamp. `DateTime.tryParse` covers ISO 8601 (with a
  /// "T" or a space separator); a short list of `intl` patterns covers the
  /// common bank/mobile-money shapes. Returns null rather than throwing —
  /// a message that otherwise matched shouldn't be discarded over a date
  /// the app doesn't yet know how to read.
  static DateTime? _parseDate(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    const patterns = [
      "d/M/yy 'at' h:mm a",
      "d/M/yyyy 'at' h:mm a",
      'd/M/yy HH:mm',
      'd/M/yyyy HH:mm',
      'd/M/yy',
      'd/M/yyyy',
    ];
    for (final p in patterns) {
      try {
        return DateFormat(p).parse(raw);
      } on FormatException {
        continue;
      }
    }
    return null;
  }
}
