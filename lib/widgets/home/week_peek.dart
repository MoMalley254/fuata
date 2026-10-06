import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// Seven small bars for the last seven days, today last and highlighted
/// (ui-design-brief.md 7.2, issue #82, finding F6).
///
/// Always exactly [spentByDay].length bars. A day with no spending still
/// draws a short track — the emptiness is the information, and a strip
/// with gaps would read as data the widget failed to load rather than
/// days nothing happened on. A dashed line sits at the daily limit when
/// one is set, which is why the bars scale to include it: a limit the
/// person is well under still needs to be on the strip, or it can never
/// say "you're getting close".
///
/// Tapping opens Summary on the week view. Each bar carries its own
/// screen-reader label ("Spent 1,200 on Tuesday"), so a person reading
/// the card by ear hears the days rather than "graphic, graphic, graphic".
class WeekPeekCard extends StatelessWidget {
  const WeekPeekCard({
    super.key,
    required this.spentByDay,
    required this.currencyCode,
    required this.onTap,
    this.dailyLimit,
    this.now,
  });

  /// Oldest first, today last. Minor units. Its length is the number of
  /// bars; a seven-day week is the default, not an assumption.
  final List<int> spentByDay;
  final String currencyCode;

  /// Shown as a dashed line; null when no daily limit is set, in which
  /// case the bars scale to the busiest day alone.
  final LimitRule? dailyLimit;

  final VoidCallback onTap;

  /// Injectable for tests and previews; production callers leave it out
  /// and get the device clock. Only used for the day names under the bars.
  final DateTime? now;

  static const _stripHeight = 64.0;
  static const _minBarHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = now ?? DateTime.now();
    final days = spentByDay.length;
    if (days == 0) return const SizedBox.shrink();

    // The tallest thing the strip has to fit: the busiest day, or the
    // limit if there is one.
    final limit = dailyLimit?.amountMinor ?? 0;
    var tallest = limit;
    for (final v in spentByDay) {
      if (v > tallest) tallest = v;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(
              color: c.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Week peek',
                    style: AppTypography.labelLg.copyWith(
                      color: c.onSurface,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: _stripHeight,
                child: Stack(
                  children: [
                    if (limit > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            color:
                            c.onSurfaceTertiary.withValues(alpha: 0.55),
                            fraction: limit / tallest,
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < days; i++) ...[
                            Expanded(
                              child: _DayBar(
                                spentMinor: spentByDay[i],
                                tallestMinor: tallest,
                                stripHeight: _stripHeight,
                                minBarHeight: _minBarHeight,
                                isToday: i == days - 1,
                                currencyCode: currencyCode,
                                day: today.subtract(
                                  Duration(days: days - 1 - i),
                                ),
                              ),
                            ),
                            if (i < days - 1)
                              const SizedBox(width: AppSpacing.xs),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  for (var i = 0; i < days; i++) ...[
                    Expanded(
                      child: Text(
                        // One letter per day, from the same date that
                        // fed the bar above — never a hardcoded "MTWTFSS",
                        // which would lie the moment the window slides.
                        DateFormat.E().format(
                          today.subtract(Duration(days: days - 1 - i)),
                        ).substring(0, 1),
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSm.copyWith(
                          color: i == days - 1
                              ? c.onSurface
                              : c.onSurfaceTertiary,
                        ),
                      ),
                    ),
                    if (i < days - 1) const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.spentMinor,
    required this.tallestMinor,
    required this.stripHeight,
    required this.minBarHeight,
    required this.isToday,
    required this.currencyCode,
    required this.day,
  });

  final int spentMinor;
  final int tallestMinor;
  final double stripHeight;
  final double minBarHeight;
  final bool isToday;
  final String currencyCode;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final available = stripHeight - minBarHeight;
    final fraction = tallestMinor <= 0
        ? 0.0
        : (spentMinor / tallestMinor).clamp(0.0, 1.0);
    final height = minBarHeight + fraction * available;

    // The issue asks for "Spent 1,200 on Tuesday". Trailing ".00" is
    // dropped so the phrasing matches a person's own reading of the
    // amount, and the currency code is included so "1,200" isn't
    // ambiguous to anyone holding more than one.
    var amount = Money(spentMinor, currencyCode).format();
    if (amount.endsWith('.00')) {
      amount = amount.substring(0, amount.length - 3);
    }
    final dayName = DateFormat.EEEE().format(day);
    final label = spentMinor == 0
        ? 'Nothing on $dayName'
        : 'Spent ${currencySymbol(currencyCode).trim()} $amount on $dayName';

    return Semantics(
      label: label,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: spentMinor == 0
              ? c.surfaceContainerHigh
              : (isToday
              ? c.primary
              : c.primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
      ),
    );
  }
}

/// A horizontal dashed line across the strip at [fraction] of its height
/// (0 = bottom, 1 = top). Used for the daily limit — a fixed line the
/// person is trying to stay under, versus the bars, which are what
/// actually happened.
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color, required this.fraction});
  final Color color;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - fraction.clamp(0.0, 1.0));
    const dash = 4.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0.0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.fraction != fraction || old.color != color;
}