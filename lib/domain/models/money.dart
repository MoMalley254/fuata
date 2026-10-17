import 'package:intl/intl.dart';

/// Shown in place of any amount while "Hide amounts in the app" is on
/// (issue #81, finding F7). A fixed run of bullets, not one per digit —
/// a length-matched mask would leak the rough size of a balance, which is
/// exactly what hiding is for.
const kHiddenAmountMask = '••••';

/// Decimal places for a currency, from intl's ISO 4217 data. Every code
/// intl knows gets the right answer; the two-decimal default only applies
/// to a code intl has never heard of, which in practice only happens on a
/// hand-edited backup file. Issue #114.
int minorUnitExponent(String currencyCode) {
  try {
    return NumberFormat.simpleCurrency(
      name: currencyCode.toUpperCase(),
      locale: 'en_US',
    ).decimalDigits ?? 2;
  } catch (_) {
    return 2;
  }
}

/// Display symbol/prefix for a currency. intl's CLDR data decides the
/// symbol; the space rule below is the only Fuata-specific thing, and
/// exists because "KSh 1,250" reads better than "KSh1,250" while
/// "$1,250" reads better than "$ 1,250". Letter-shaped symbols get a
/// trailing space, punctuation symbols don't. Issue #114.
String currencySymbol(String currencyCode) {
  String symbol;
  try {
    final s = NumberFormat.simpleCurrency(
      name: currencyCode.toUpperCase(),
      locale: 'en_US',
    ).currencySymbol;
    symbol = s.isNotEmpty ? s : '${currencyCode.toUpperCase()} ';
  } catch (_) {
    symbol = '${currencyCode.toUpperCase()} ';
  }
  if (symbol.isNotEmpty &&
      !symbol.endsWith(' ') &&
      RegExp(r'^[A-Za-z]').hasMatch(symbol)) {
    return '$symbol ';
  }
  return symbol;
}

int pow10(int exponent) {
  var r = 1;
  for (var i = 0; i < exponent; i++) {
    r *= 10;
  }
  return r;
}

/// All amounts in the app are integers in the currency's minor unit
/// (e.g. cents). Never use double for money (ADR-003). `majorValue`
/// exists only to bridge into widgets built around double + symbol
/// (StatusRingCard, UnitCard, TransactionRow) — never store or do
/// arithmetic on it.
class Money {
  final int minor;
  final String currencyCode;

  const Money(this.minor, this.currencyCode);

  factory Money.zero(String currencyCode) => Money(0, currencyCode);

  /// Parses a human-entered major-unit string ("1,250.50") into Money.
  /// Throws FormatException on invalid input.
  factory Money.parseMajor(String input, String currencyCode) {
    final cleaned = input.replaceAll(',', '').trim();
    if (cleaned.isEmpty) throw const FormatException('Empty amount');
    final exponent = minorUnitExponent(currencyCode);
    final parts = cleaned.split('.');
    final wholePart = int.parse(parts[0].isEmpty ? '0' : parts[0]);
    int fractionPart = 0;
    if (parts.length > 1 && exponent > 0) {
      final frac = parts[1].padRight(exponent, '0').substring(0, exponent);
      fractionPart = int.parse(frac);
    }
    final factor = pow10(exponent);
    final sign = cleaned.startsWith('-') ? -1 : 1;
    return Money(sign * (wholePart.abs() * factor + fractionPart), currencyCode);
  }

  Money operator +(Money other) {
    assert(currencyCode == other.currencyCode, 'Currency mismatch');
    return Money(minor + other.minor, currencyCode);
  }

  Money operator -(Money other) {
    assert(currencyCode == other.currencyCode, 'Currency mismatch');
    return Money(minor - other.minor, currencyCode);
  }

  Money operator -() => Money(-minor, currencyCode);

  bool get isNegative => minor < 0;
  bool get isZero => minor == 0;

  /// Double major-unit value, e.g. 125050 minor -> 1250.50. Display-only
  /// bridge for widgets that take double + a currency symbol string.
  double get majorValue => minor / pow10(minorUnitExponent(currencyCode));

  /// Formatted for display, e.g. "1,250.50".
  String format({bool showSign = false}) {
    final exponent = minorUnitExponent(currencyCode);
    final divisor = pow10(exponent);
    final major = minor.abs() / divisor;
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: exponent,
    );
    final formatted = formatter.format(major).trim();
    final sign = minor < 0 ? '-' : (showSign ? '+' : '');
    return '$sign$formatted';
  }

  @override
  String toString() => '${format()} $currencyCode';
}