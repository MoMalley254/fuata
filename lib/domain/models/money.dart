import 'package:intl/intl.dart';

/// Number of decimal places for a currency's minor unit.
/// unknown codes default to 2 (matches ADR-003).
int minorUnitExponent(String currencyCode) {
  const zeroDecimal = {'JPY', 'UGX', 'KRW', 'VND', 'CLP'};
  return zeroDecimal.contains(currencyCode.toUpperCase()) ? 0 : 2;
}

/// All amounts in the app are integers in the currency's minor unit
/// (e.g. cents). (ADR-003).
class Money {
  final int minor;
  final String currencyCode;

  const Money(this.minor, this.currencyCode);

  factory Money.zero(String currencyCode) => Money(0, currencyCode);

  /// Parses a human-entered major-unit string ("1,250.50") into Money.
  /// Throws FormatException on invalid input.
  factory Money.parseMajor(String input, String currencyCode) {
    final cleaned = input.replaceAll(',', '').trim();
    if (cleaned.isEmpty) throw const FormatException('Empty Amount');
    final exponent = minorUnitExponent(currencyCode);
    final parts = cleaned.split('.');
    final wholePart = int.parse(parts[0].isEmpty ? '0' : parts[0]);
    int fractionPart = 0;
    if (parts.length > 1 && exponent > 0) {
      final frac = parts[1].padRight(exponent, '0').substring(0, exponent);
      fractionPart = int.parse(frac);
    }
    final factor = _pow10(exponent);
    final sign = cleaned.startsWith('-') ? -1 : 1;
    return Money(
      sign * (wholePart.abs() * factor + fractionPart),
      currencyCode,
    );
  }

  static int _pow10(int exponent) {
    var r = 1;
    for (var i = 0; i < exponent; i++) {
      r *= 10;
    }
    return r;
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

  /// Formatted for display, e.g. "1,250.50".
  String format({bool showSign = false}) {
    final exponent = minorUnitExponent(currencyCode);
    final divisor = _pow10(exponent);
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
