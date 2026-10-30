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
  final Map<String, String> custom;

  /// #72 (F11c): fields the person labelled but whose text couldn't be
  /// read as that kind of value (e.g. a date in a shape we don't know),
  /// keyed by field type with the raw text. Lets the Found card tell
  /// "labelled but unreadable" apart from "never labelled".
  final Map<TemplateFieldType, String> unreadable;

  const ParsedFields({
    this.amountMinor,
    this.feeMinor,
    this.balanceAfterMinor,
    this.code,
    this.occurredAt,
    this.counterparty,
    this.custom = const {},
    this.unreadable = const {},
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
      final unreadable = <TemplateFieldType, String>{};
      final custom = <String, String>{};

      for (final entry in template.fieldMap.entries) {
        final raw = match.namedGroup(entry.key);
        if (raw == null) continue;
        switch (entry.value) {
          case TemplateFieldType.amount:
            amountMinor = _parseAmountMinor(raw, currencyCode);
            break;
          case TemplateFieldType.fee:
            feeMinor = _parseAmountMinor(raw, currencyCode);
            if (feeMinor == null) unreadable[entry.value] = raw.trim();
            break;
          case TemplateFieldType.balance:
            balanceAfterMinor = _parseAmountMinor(raw, currencyCode);
            if (balanceAfterMinor == null) unreadable[entry.value] = raw.trim();
            break;
          case TemplateFieldType.code:
            // Several codes in one message: the last labelled one wins
            // (documented in issue-26 F11d; split into reference vs other
            // code later).
            code = raw.trim();
            break;
          case TemplateFieldType.date:
            occurredAt = _parseDate(raw.trim());
            if (occurredAt == null) unreadable[entry.value] = raw.trim();
            break;
          case TemplateFieldType.person:
            counterparty = raw.trim();
            break;
          case TemplateFieldType.custom:
            final name = template.customFieldNames[entry.key] ?? entry.key;
            custom[name] = raw.trim();
            break;
          case TemplateFieldType.wildcard:
            // Never in fieldMap: wildcard spans are non-capturing and
            // carry no data.
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
          unreadable: unreadable,
          custom: custom,
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

  ///#20 Parses one labeled money capture. Returns null instead of throwing —
  /// a labeled field that we can't parse should be reported as "not found"
  /// for that field, never abort the whole parse. (Amount's null is then
  /// treated as "no match" by the caller; fee/balance's null just means
  /// those rows show as "not labeled".)
  static int? _parseAmountMinor(String raw, String currencyCode) {
    final stripped = raw
        .replaceFirst(RegExp(r'^[A-Za-z]{2,5}\.?\s*'), '')
        .replaceAll(RegExp(r'[.,;:!?]+$'), '')
        .trim();
    if (stripped.isEmpty) return null;
    try {
      return Money.parseMajor(stripped, currencyCode).minor;
    } on FormatException {
      return null;
    }
  }

  /// Date shapes tried after [_normaliseDate], most specific first. Order
  /// matters: 12-hour (with AM/PM) before 24-hour and time before date-only,
  /// so a pattern that would stop early never wins over the full one. Day
  /// first (d/M), as everywhere this app's messages come from. `yyyy` is
  /// tried before `yy`; a two-digit year read by `yyyy` gives year 26 AD,
  /// which [_parseDate] rejects, so `yy` then handles it.
  static final List<String> _datePatterns = () {
    const dates = [
      'd/M/yyyy',
      'd/M/yy',
      'd MMM yyyy',
      'd MMM yy',
      'd MMMM yyyy',
      'd-MMM-yyyy',
      'd-MMM-yy',
    ];
    const times = ['h:mm:ss a', 'h:mm a', 'HH:mm:ss', 'HH:mm'];
    const joiners = [" 'at' ", ' '];
    return [
      for (final d in dates)
        for (final t in times)
          for (final j in joiners) '$d$j$t',
      ...dates,
    ];
  }();

  /// Makes the many ways a message writes a date line up with
  /// [_datePatterns]: drops a leading "on"/"at", lowercases "at", writes
  /// AM/PM as " AM"/" PM", turns "-" and "." between numbers into "/" (so
  /// 28-09-2026 and 28.09.2026 read like 28/09/2026), and collapses
  /// commas and repeated spaces. "28-Sep-26" keeps its hyphens.
  static String _normaliseDate(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^(?:on|at)\s+', caseSensitive: false), '');
    s = s.replaceAll(',', ' ');
    s = s.replaceAllMapped(
      RegExp(r'\bat\b', caseSensitive: false),
      (_) => 'at',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\d)\s*([AaPp])\.?[Mm]\.?(?![A-Za-z])'),
      (m) => '${m[1]} ${m[2]!.toUpperCase()}M',
    );
    s = s.replaceAllMapped(RegExp(r'(\d)[-.](?=\d)'), (m) => '${m[1]}/');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// testing.md P-09 and #72 (F11c): "21/9/26 at 1:12 PM", "28-09-2026
  /// 11:03 PM", "28 Sep 2026", "28-Sep-26 14:05" and ISO all need to parse
  /// to the correct timestamp. `DateTime.tryParse` covers ISO 8601 (with a
  /// "T" or a space separator); [_normaliseDate] plus [_datePatterns] cover
  /// the day-first bank/mobile-money shapes. Returns null rather than
  /// throwing — a message that otherwise matched shouldn't be discarded
  /// over a date the app doesn't yet know how to read (the Found card
  /// shows a "couldn't read" state for it).
  static DateTime? _parseDate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[.,;:!?]+$'), '').trim();
    if (cleaned.isEmpty) return null;

    final iso = DateTime.tryParse(cleaned);
    if (iso != null) return iso;

    final normalised = _normaliseDate(cleaned);
    if (normalised.isEmpty) return null;
    final isoAgain = DateTime.tryParse(normalised);
    if (isoAgain != null) return isoAgain;

    for (final p in _datePatterns) {
      try {
        //#20
        // Pin the locale: without it DateFormat uses the device locale,
        // which may not have a 12-hour AM/PM pattern defined and can fail
        // to parse "10:19 AM" on some devices.
        final parsed = DateFormat(p, 'en_US').parse(normalised);
        // `yyyy` reading a two-digit year yields year 26 AD: not a date
        // we want, so let the `yy` pattern have it.
        if (parsed.year < 1900) continue;
        return parsed;
      } on FormatException {
        continue;
      }
    }
    return null;
  }
}
