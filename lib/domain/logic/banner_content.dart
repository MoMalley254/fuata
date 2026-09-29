// ---------------------------------------------------------------------------
// What the notification banner says (issues #16 / #17, US-05,
// ui-design-brief.md 7.9-7.10).
//
// Pure Dart, no widgets: the banner setup screen's live preview (#17) and
// the real ongoing notification (#16) both call BannerContent.build(), so
// what the person sees in the preview is exactly what Android will show.
// ---------------------------------------------------------------------------

import '../models/limit_rule.dart';
import '../models/money.dart';
import '../models/settings.dart';
import '../models/unit.dart';

class BannerContent {
  final SpendStatus status;

  /// Collapsed headline, e.g. "🟢 1,500 left today".
  final String title;

  /// 0..1 share of today's limit used; null when hidden or no daily limit.
  final double? progress;

  /// Expanded body: one "Cash 760" entry per shown unit (empty when redacted).
  final List<String> unitLines;

  /// Expanded body: "Spent today 1,500" (null when redacted).
  final String? spentLine;

  final bool showQuickAdd;

  const BannerContent({
    required this.status,
    required this.title,
    required this.progress,
    required this.unitLines,
    required this.spentLine,
    required this.showQuickAdd,
  });

  static BannerContent build({
    required SpendStatus status,
    required int spentToday,
    required LimitRule? dailyLimit,
    required List<MoneyUnit> units,
    required Map<String, int> balanceByUnit,
    required BannerHeadline headline,
    required Set<String> selectedUnitIds, // empty = every unit
    required bool showProgress,
    required bool showQuickAdd,
    required bool redacted,

}) {
    final active = units.where((u) => !u.archived).toList();
    final shown = active
        .where((u) => selectedUnitIds.isEmpty || selectedUnitIds.contains(u.id))
        .toList();

    final code =
        dailyLimit?.currencyCode ??
            (active.isEmpty ? 'KES' : active.first.currencyCode);
    String fmt(int minor) => Money(minor, code).format();

    final emoji = status.emoji;
    final left = dailyLimit == null ? null : dailyLimit.amountMinor - spentToday;

    final String title;
    if (redacted) {
// Lock-screen version: words only, never an amount.
      title = '$emoji ${status.label}';
    } else {
switch(headline) {
  case BannerHeadline.leftToday:
    if (left == null) {
      title = '$emoji Spent ${fmt(spentToday)} today';
    } else if (left < 0) {
      title = '$emoji Over by ${fmt(-left)}';
    } else if (left == 0) {
      title = '$emoji Nothing left today';
    } else {
      title = '$emoji ${fmt(left)} left today';
    }
  case BannerHeadline.spentToday:
    title = '$emoji Spent ${fmt(spentToday)} today';
  case BannerHeadline.totalIHave:
  // Only units in the banner's currency are summed: adding KES to
  // USD would be a made-up number.
    final total = shown
        .where((u) => u.currencyCode == code)
        .fold<int>(0, (sum, u) => sum + (balanceByUnit[u.id] ?? 0));
    title = '$emoji ${fmt(total)} in total';
}
    }

    double? progress;
    if (showProgress && dailyLimit != null && dailyLimit.amountMinor > 0) {
      progress = (spentToday / dailyLimit.amountMinor).clamp(0.0, 1.0);
    }

    return BannerContent(
      status: status,
      title: title,
      progress: progress,
      unitLines: redacted
          ? const []
          : [
        for (final u in shown)
          '${u.name} ${Money(balanceByUnit[u.id] ?? 0, u.currencyCode).format()}',
      ],
      spentLine: redacted ? null : 'Spent today ${fmt(spentToday)}',
      showQuickAdd: showQuickAdd,
    );
  }
}