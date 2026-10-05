// ---------------------------------------------------------------------------
// What the home-screen widget shows (issue #29).
//
// Pure Dart: the same shape as the notification banner's BannerContent,
// but a strict subset, because RemoteViews can only render a handful of
// views and everything crosses a method channel as a plain map.
//
// The widget is a mirror of the ongoing banner's *number*, not its
// options: it always shows today, in the first unit's currency, with the
// person's daily limit if they set one.
// ---------------------------------------------------------------------------

import '../models/limit_rule.dart';
import '../models/money.dart';
import '../models/transaction.dart';
import '../models/unit.dart';
import 'ledger.dart';

class WidgetSnapshot {
  /// The big number, already formatted without a currency prefix,
  /// e.g. "1,500" or "1,234.56". Widgets are cramped; trailing ".00" is
  /// trimmed.
  final String amount;

  /// Currency prefix shown next to the amount, e.g. "KSh".
  final String currency;

  /// Small word under/next to the amount: "left today", "over today",
  /// "spent today", "nothing left".
  final String caption;

  /// 0..1 when a daily limit exists, otherwise null (no bar to draw).
  final double? progress;

  /// Single emoji for the status dot, from SpendStatus.emoji.
  final String emoji;

  /// The status name (`safe`, `warning`, `danger`, `overdraft`) so the
  /// native side can pick the caption's colour.
  final String status;

  const WidgetSnapshot({
    required this.amount,
    required this.currency,
    required this.caption,
    required this.progress,
    required this.emoji,
    required this.status,
  });

  /// Plain map for the channel. Progress uses -1.0 for "no bar" so the
  /// map has no nulls: a `JSONObject` on the Kotlin side would reject a
  /// null value, and RemoteViews wants a primitive anyway.
  Map<String, Object?> toJson() => {
    'amount': amount,
    'currency': currency,
    'caption': caption,
    'progress': progress ?? -1.0,
    'emoji': emoji,
    'status': status,
  };

  /// From the raw pieces. [amountMinor] has already been picked to be the
  /// positive number the widget shows, whatever the caption is.
  static WidgetSnapshot build({
    required SpendStatus status,
    required int spentToday,
    required LimitRule? dailyLimit,
    required String currencyCode,
  }) {
    final symbol = currencySymbol(currencyCode).trim();
    final left = dailyLimit == null
        ? null
        : dailyLimit.amountMinor - spentToday;

    final String caption;
    final int amountMinor;
    if (left == null) {
      caption = 'spent today';
      amountMinor = spentToday;
    } else if (left < 0) {
      caption = 'over today';
      amountMinor = -left;
    } else if (left == 0) {
      caption = 'nothing left';
      amountMinor = 0;
    } else {
      caption = 'left today';
      amountMinor = left;
    }

    var text = Money(amountMinor, currencyCode).format();
    if (text.endsWith('.00')) text = text.substring(0, text.length - 3);

    return WidgetSnapshot(
      amount: text,
      currency: symbol,
      caption: caption,
      progress: (dailyLimit == null || dailyLimit.amountMinor <= 0)
          ? null
          : (spentToday / dailyLimit.amountMinor).clamp(0.0, 1.0),
      emoji: status.emoji,
      status: status.name,
    );
  }

  /// From whole lists, for callers that already have them loaded — the
  /// UI isolate (via HomeState) and the notification listener's
  /// background isolate both do.
  static WidgetSnapshot fromData({
    required List<MoneyUnit> units,
    required List<MoneyTransaction> transactions,
    required List<LimitRule> limits,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final (start, end) = Ledger.todayRange(at);
    final spentToday = Ledger.spentInPeriod(transactions, start, end);

    LimitRule? daily;
    for (final l in limits) {
      if (l.enabled &&
          l.scope == LimitScope.overall &&
          l.period == LimitPeriod.day) {
        daily = l;
        break;
      }
    }

    final currency = units.isNotEmpty ? units.first.currencyCode : 'KES';
    return WidgetSnapshot.build(
      status: Ledger.statusFor(daily, spentToday),
      spentToday: spentToday,
      dailyLimit: daily,
      currencyCode: currency,
    );
  }
}