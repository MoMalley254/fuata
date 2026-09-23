import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_status.dart';
import '../ui/theme/app_typography.dart';
import 'status_pill.dart';

/// Hero status ring card — the daily "am I okay to spend?" answer.
class StatusRingCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = status.fg(c);

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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$currencySymbol${_fmt(remaining)}',
                            style: AppTypography.displayHeroMobile
                                .copyWith(color: c.onSurface),
                          ),
                          const SizedBox(height: 8),
                          StatusPill(status: status),
                          const SizedBox(height: 6),
                          Text(
                            caption,
                            style: AppTypography.bodySm
                                .copyWith(color: c.onSurfaceVariant),
                          ),
                        ],
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