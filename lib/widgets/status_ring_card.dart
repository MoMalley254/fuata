import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import '../domain/models/money.dart';
import '../ui/providers/app_providers.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_status.dart';
import '../ui/theme/app_typography.dart';
import 'status_pill.dart';

/// Hero status ring card — the daily "am I okay to spend?" answer.
class StatusRingCard extends ConsumerWidget {
  const StatusRingCard({
    super.key,
    required this.remaining,
    required this.spent,
    required this.limit,
    required this.status,
    this.caption = 'resets at midnight',
    this.currencySymbol = '\$',
    this.onTap,
  });

  final double remaining;
  final double spent;
  final double limit;
  final SpendStatus status;
  final String caption;
  final String currencySymbol;
  final VoidCallback? onTap;

  double get _progress =>
      limit <= 0 ? 0 : (spent / limit).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final accent = status.fg(c);
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;

    // Issue #110: build the displayed string once, so the length check
    // that picks the style and the Text that renders it can't disagree.
    final displayText = hidden
        ? kHiddenAmountMask
        : '$currencySymbol${_fmt(remaining)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusHero),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadiusHero),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: _progress,
                      track: c.surfaceContainerHigh,
                      accent: accent,
                    ),
                    child: Center(
                      child: Padding(
                        // Issue #110: keep the content off the ring without squeezing the
                        // status pill. AppSpacing.sm each side leaves 184 dp inside the
                        // 200 dp box; the ring's inner edge sits at ~176 dp.
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Issue #110: the number, so a very large amount can never
                            // clip the ring or push the pill off the card.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayText,
                                maxLines: 1,
                                softWrap: false,
                                style: _heroNumberStyle(
                                  displayText: displayText,
                                  color: c.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Also FittedBoxed: "Almost at your limit" at labelSm is wider
                            // than the ring's inner width, and a large amount leaves no
                            // room to spare. Previously this line only survived because
                            // the number above it was short.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: StatusPill(status: status),
                            ),
                            const SizedBox(height: 6),
                            // The caption is allowed to wrap, so it doesn't need a
                            // FittedBox — just enough width to break on its spaces.
                            Text(
                              caption,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySm
                                  .copyWith(color: c.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return v < 0 ? '-${buf.toString()}' : buf.toString();
  }

  /// Issue #110: start a long hero number one size down so FittedBox
  /// has less shrinking to do. Ten characters is about where
  /// displayHeroMobile (36 px) stops fitting the ring's inner width
  /// once the currency prefix and the horizontal padding are counted.
  static TextStyle _heroNumberStyle({
    required String displayText,
    required Color color,
  }) {
    final base = displayText.length <= 10
        ? AppTypography.displayHeroMobile
        : AppTypography.headlineLg;
    return base.copyWith(color: color);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.accent});
  final double progress;
  final Color track;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [accent.withValues(alpha: 0.65), accent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent || old.track != track;
}