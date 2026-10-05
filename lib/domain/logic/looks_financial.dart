// ---------------------------------------------------------------------------
// "Does this notification look like it's about money?" (issue #74, US-10)
//
// Fuata keeps a notification from a watched app as "Couldn't read this"
// only when it might be a payment. Everything else — chats, delivery
// updates, OTPs — is dropped at the pipeline boundary and never reaches
// the database or a backup.
//
// The bar is deliberately high: a false negative costs a "Teach me"
// prompt (the person can paste the message by hand if they want), a
// false positive costs a private chat in the database. When in doubt,
// drop.
// ---------------------------------------------------------------------------

class LooksFinancial {
  LooksFinancial._();

  /// Currency tokens common in the messages Fuata sees. `\b` around the
  /// word-shaped ones so "KESHO" (Swahili for tomorrow) can't match
  /// "KSH"; the `/=` shorthand isn't word-shaped, so it stands alone.
  static final _currencyWord = RegExp(
    // \b on the left stops "KESHO" matching "KSH". On the right, allow a
    // digit OR a boundary, so "Ksh350", "KES 500" and a bare "KSH" all
    // match, but "KESHO" (next char H) still doesn't.
    r'\b(?:KES|KSH|Ksh|USh|TSh|NGN|GHS|ZAR|USD|EUR|GBP)(?=\d|\b)',
    caseSensitive: false,
  );
  static final _currencySym = RegExp(r'/=');

  /// A number that reads like an amount: has thousands separators or a
  /// two-decimal tail. A bare integer doesn't count — "3 new messages"
  /// mustn't match, and a message with no shape at all ("pay 1200") is
  /// close enough to noise that the person pasting it by hand is a
  /// better story than a false positive.
  static final _moneyAmount = RegExp(r'\d[\d,]*(?:\.\d{1,2})?');

  /// Words a message uses when it's about a payment. Kept tight and
  /// lowercase; matched case-insensitively.
  static final _moneyWords = RegExp(
    r'\b(?:sent|received|paid|pay|debited|credited|credited|transferred|'
    r'transfer|withdraw|withdrew|deposited|deposit|balance|bal)\b',
    caseSensitive: false,
  );

  /// Words that flag a one-time code.
  static final _otpWords = RegExp(
    r'\b(?:code|otp|pin|password|verification|verify)\b',
    caseSensitive: false,
  );

  /// A short run of digits — 4 to 8, the usual length of an OTP.
  static final _codeShaped = RegExp(r'\b\d{4,8}\b');

  /// True when the text could plausibly be a payment message Fuata
  /// should offer to teach. One-time codes are always false, even when
  /// the surrounding text also looks financial.
  static bool check(String text) {
    if (text.trim().isEmpty) return false;
    if (_looksLikeOneTimeCode(text)) return false;
    if (_currencyWord.hasMatch(text)) return true;
    if (_currencySym.hasMatch(text)) return true;
    return _hasAmountNearMoneyWord(text);
  }

  /// A number with a money shape (comma or decimals) inside a short
  /// window around one of [_moneyWords]. 80 characters each side is
  /// about one SMS clause; enough to catch "paid 1,500 to ...", not so
  /// much that a stray "balance" word elsewhere trips it.
  static bool _hasAmountNearMoneyWord(String text) {
    for (final m in _moneyAmount.allMatches(text)) {
      final raw = m[0]!;
      final hasMoneyShape = raw.contains(',') || raw.contains('.');
      if (!hasMoneyShape) continue;
      final start = (m.start - 80).clamp(0, text.length);
      final end = (m.end + 80).clamp(0, text.length);
      if (_moneyWords.hasMatch(text.substring(start, end))) return true;
    }
    return false;
  }

  /// A 4-to-8-digit run inside a short window around a code-ish word.
  /// 40 characters each side catches "Your code is 445566" and
  /// "Verify with 1234 to confirm ..." without spanning the whole
  /// message.
  static bool _looksLikeOneTimeCode(String text) {
    for (final m in _codeShaped.allMatches(text)) {
      final start = (m.start - 40).clamp(0, text.length);
      final end = (m.end + 40).clamp(0, text.length);
      if (_otpWords.hasMatch(text.substring(start, end))) return true;
    }
    return false;
  }
}