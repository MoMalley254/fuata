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
import '../models/outing.dart';
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
    required BannerUnitsMode unitsMode,
    required Set<String> selectedUnitIds, // empty = every unit
    required bool showProgress,
    required bool showQuickAdd,
    required bool redacted,

    /// #30: when an outing is active, the banner answers "how is the
    /// trip going?" instead of "how is today going". Overrides the
    /// headline number; the units split and the spent line stay the same
    /// (they answer "what do I have" and "what did I spend", which don't
    /// change during an outing).
    Outing? activeOuting,
    int outingSpentMinor = 0,
    SpendStatus? outingStatus,
  }) {
    final active = units.where((u) => !u.archived).toList();
    // The units whose balance *lines* appear in the expanded body.
    final linesFor = switch (unitsMode) {
      BannerUnitsMode.all => active,
      BannerUnitsMode.selected =>
        active.where((u) => selectedUnitIds.contains(u.id)).toList(),
      BannerUnitsMode.none => const <MoneyUnit>[],
    };

    // The units whose balances roll up into the "total I have" headline.
    // `none` is about the split lines, not about the total reading zero,
    // so the headline still sums every active unit — the same number the
    // person would see in My money.
    final unitsForTotal = unitsMode == BannerUnitsMode.none ? active : linesFor;

    // Effective status and limit: outing wins when active.
    final SpendStatus effectiveStatus = activeOuting != null
        ? (outingStatus ?? SpendStatus.safe)
        : status;
    final LimitRule? effectiveLimit = activeOuting != null
        ? activeOuting.asLimit()
        : dailyLimit;
    final int effectiveSpent = activeOuting != null
        ? outingSpentMinor
        : spentToday;

    final code = activeOuting != null
        ? activeOuting.currencyCode
        : (effectiveLimit?.currencyCode ??
              (active.isEmpty ? 'KES' : active.first.currencyCode));
    String fmt(int minor) => Money(minor, code).format();

    final emoji = effectiveStatus.emoji;
    final left = effectiveLimit == null
        ? null
        : effectiveLimit.amountMinor - effectiveSpent;

    final String title;
    if (redacted) {
      title = '$emoji ${effectiveStatus.label}';
    } else if (activeOuting != null) {
      // "Mombasa trip" is the noun; "left" / "over" is the verb.
      final name = activeOuting.name;
      if (left == null || left >= 0) {
        title = '$emoji ${fmt(left ?? 0)} left for $name';
      } else {
        title = '$emoji Over by ${fmt(-left)} for $name';
      }
    } else {
      switch (headline) {
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
          final total = unitsForTotal
              .where((u) => u.currencyCode == code)
              .fold<int>(0, (sum, u) => sum + (balanceByUnit[u.id] ?? 0));
          title = '$emoji ${fmt(total)} in total';
      }
    }

    // Progress: use effective limit.
    double? progress;
    if (showProgress &&
        effectiveLimit != null &&
        effectiveLimit.amountMinor > 0) {
      progress = (effectiveSpent / effectiveLimit.amountMinor).clamp(0.0, 1.0);
    }

    return BannerContent(
      status: effectiveStatus,
      title: title,
      progress: progress,
      unitLines: redacted
          ? const []
          : [
        for (final u in linesFor)
          '${u.name} '
              '${Money(balanceByUnit[u.id] ?? 0, u.currencyCode).format()}',
      ],
      spentLine: redacted
          ? null
          : (activeOuting != null
          ? 'Spent ${fmt(outingSpentMinor)} of '
          '${fmt(activeOuting.amountMinor)}'
          : 'Spent today ${fmt(effectiveSpent)}'),
      showQuickAdd: showQuickAdd,
    );
  }
}
