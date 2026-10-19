// ---------------------------------------------------------------------------
// What the home-screen widget shows (issue #29, options from #113).
//
// Pure Dart: the same shape as the notification banner's BannerContent,
// but a strict subset, because RemoteViews can only render a handful of
// views and everything crosses a method channel as a plain map.
//
// The widget is a mirror of the banner's *number*, not its options: it
// always shows today, in the first unit's currency, with the person's
// daily limit if they set one. What #113 added is which number, which
// units appear in the split, and whether the progress bar and split line
// are drawn at all.
// ---------------------------------------------------------------------------

import '../models/limit_rule.dart';
import '../models/money.dart';
import '../models/settings.dart';
import '../models/unit.dart';
import '../repositories/repositories.dart';
import 'ledger.dart';

class WidgetSnapshot {
  /// The big number, already formatted without a currency prefix,
  /// e.g. "1,500" or "1,234.56". Widgets are cramped; trailing ".00" is
  /// trimmed.
  final String amount;

  /// Currency prefix shown next to the amount, e.g. "KSh".
  final String currency;

  /// Small word under/next to the amount: "left today", "over today",
  /// "spent today", "in total", "nothing left".
  final String caption;

  /// 0..1 when a daily limit exists and the progress bar is switched on,
  /// otherwise null (no bar to draw).
  final double? progress;

  /// Single emoji for the status dot, from SpendStatus.emoji.
  final String emoji;

  /// The status name (`safe`, `warning`, `danger`, `overdraft`) so the
  /// native side can pick the caption's colour.
  final String status;

  /// "Cash 760 · Mobile 3,450" — the split line on the rich layout.
  /// Empty when [widgetShowSplit] is off, when the mode is `none`, or
  /// when no active unit is in the widget's currency. Native hides the
  /// line rather than showing an empty one.
  final String splitLine;

  /// How the widget should lay itself out. `auto` lets the native side
  /// pick compact/rich from the cell width it was given; `compact` and
  /// `rich` force one regardless.
  final WidgetVariant variant;

  const WidgetSnapshot({
    required this.amount,
    required this.currency,
    required this.caption,
    required this.progress,
    required this.emoji,
    required this.status,
    this.splitLine = '',
    this.variant = WidgetVariant.auto,
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
    'splitLine': splitLine,
    'variant': variant.name,
  };

  /// From the raw pieces. [amountMinor] has already been picked to be the
  /// positive number the widget shows, whatever the caption is.
  ///
  /// Every new parameter from #113 has a default that reproduces the
  /// pre-#113 shape (left today, all units, no split line), so an old
  /// caller or test keeps compiling and keeps meaning the same thing.
  static WidgetSnapshot build({
    required SpendStatus status,
    required int spentToday,
    required LimitRule? dailyLimit,
    required String currencyCode,
    // #113 options — all default to the pre-#113 behaviour.
    BannerHeadline headline = BannerHeadline.leftToday,
    BannerUnitsMode unitsMode = BannerUnitsMode.all,
    Set<String> selectedUnitIds = const {},
    bool showProgress = true,
    bool showSplit = false,
    WidgetVariant variant = WidgetVariant.auto,
    List<MoneyUnit> units = const [],
    Map<String, int> balanceByUnit = const {},
  }) {
    final active = units.where((u) => !u.archived).toList();

    // Which units' balances feed the "total I have" headline and the
    // split line. Mirrors BannerContent.build exactly: `none` is about
    // the *split*, not about the total reading zero.
    final linesFor = switch (unitsMode) {
      BannerUnitsMode.all => active,
      BannerUnitsMode.selected =>
          active.where((u) => selectedUnitIds.contains(u.id)).toList(),
      BannerUnitsMode.none => const <MoneyUnit>[],
    };
    final unitsForTotal = unitsMode == BannerUnitsMode.none ? active : linesFor;

    final symbol = currencySymbol(currencyCode).trim();
    final left = dailyLimit == null
        ? null
        : dailyLimit.amountMinor - spentToday;

    final String caption;
    final int amountMinor;
    switch (headline) {
      case BannerHeadline.leftToday:
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
      case BannerHeadline.spentToday:
        caption = 'spent today';
        amountMinor = spentToday;
      case BannerHeadline.totalIHave:
        var total = 0;
        for (final u in unitsForTotal) {
          if (u.currencyCode != currencyCode) continue;
          total += balanceByUnit[u.id] ?? 0;
        }
        caption = 'in total';
        amountMinor = total;
    }

    var text = Money(amountMinor, currencyCode).format();
    if (text.endsWith('.00')) text = text.substring(0, text.length - 3);

    // The split line is only meaningful on the rich layout; the caller
    // decides whether to *draw* it (via variant + the cell width), but
    // if it's switched off or nothing would go in it, ship the empty
    // string so native never has to guess.
    final split = (showSplit && linesFor.isNotEmpty)
        ? linesFor
        .where((u) => u.currencyCode == currencyCode)
        .map((u) =>
    '${u.name} '
        '${Money(balanceByUnit[u.id] ?? 0, u.currencyCode).format()}')
        .join(' · ')
        : '';

    return WidgetSnapshot(
      amount: text,
      currency: symbol,
      caption: caption,
      progress: (!showProgress || dailyLimit == null || dailyLimit.amountMinor <= 0)
          ? null
          : (spentToday / dailyLimit.amountMinor).clamp(0.0, 1.0),
      emoji: status.emoji,
      status: status.name,
      splitLine: split,
      variant: variant,
    );
  }
}

/// Builds the widget's snapshot from the same repositories the rest of
/// the app reads — the UI isolate (via widget_providers.dart) and the
/// notification listener's background isolate (via notification_capture)
/// both call this, exactly as they both call loadBannerContent.
///
/// Never returns null: the widget is on the home screen or it isn't;
/// there is no "off" state for the data. If the person wants it gone,
/// they remove it from the launcher.
Future<WidgetSnapshot> loadWidgetSnapshot({
  required UnitRepository units,
  required TransactionRepository transactions,
  required LimitRepository limits,
  required SettingsRepository settings,
  DateTime Function()? now,
}) async {
  final clock = now ?? DateTime.now;

  final s = await settings.watchSettings().first;
  final unitList = await units.watchUnits().first;
  final txList = await transactions.watchTransactions().first;
  final limitList = await limits.watchLimits().first;

  final (start, end) = Ledger.todayRange(clock());
  final spentToday = Ledger.spentInPeriod(txList, start, end);

  LimitRule? daily;
  for (final l in limitList) {
    if (l.enabled &&
        l.scope == LimitScope.overall &&
        l.period == LimitPeriod.day) {
      daily = l;
      break;
    }
  }

  final currency = unitList.isNotEmpty ? unitList.first.currencyCode : 'KES';
  final balanceByUnit = {
    for (final u in unitList) u.id: Ledger.balanceOf(u, txList),
  };

  return WidgetSnapshot.build(
    status: Ledger.statusFor(daily, spentToday),
    spentToday: spentToday,
    dailyLimit: daily,
    currencyCode: currency,
    headline: s.widgetHeadline,
    unitsMode: s.widgetUnitsMode,
    selectedUnitIds: s.widgetUnitIds,
    showProgress: s.widgetShowProgress,
    showSplit: s.widgetShowSplit,
    variant: s.widgetVariant,
    units: unitList,
    balanceByUnit: balanceByUnit,
  );
}