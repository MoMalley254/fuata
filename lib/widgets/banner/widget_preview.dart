import 'package:flutter/material.dart';

import '../../domain/logic/widget_content.dart';
import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// A mock of the home-screen widget as Android draws it (issue #113).
///
/// Purely presentational: every field it draws comes from a real
/// [WidgetSnapshot], the same one FuataWidgetProvider renders — so what
/// the person sees here is what lands on their home screen. The only
/// thing this does that Android doesn't is *decide* the variant; the
/// real widget picks compact/rich from the cell width, and this widget
/// has no cell to measure, so it takes [variant] as a parameter.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.snapshot,
    required this.variant,
    this.width = 260,
  });

  final WidgetSnapshot snapshot;

  /// Resolved variant to draw. The setup screen passes the person's
  /// choice here, or `WidgetVariant.auto`'s rich look when they want to
  /// see what a wide cell gives them.
  final WidgetVariant variant;
  final double width;

  bool get _rich =>
      variant == WidgetVariant.rich ||
          (variant == WidgetVariant.auto && width >= 240);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = _statusColor(c, snapshot.status);

    // The mock uses the same surfaces the widget's own drawable does —
    // AppColors.surface in place of @color/widget_surface, the border
    // radius the drawable declares. It should look like the app, not
    // like a screenshot of Android.
    return Center(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          border: Border.all(
            color: c.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(snapshot.emoji, style: const TextStyle(fontSize: 18)),
                const Spacer(),
                Text(
                  snapshot.caption,
                  style: AppTypography.bodySm.copyWith(color: status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (snapshot.currency.isNotEmpty) ...[
                  Text(
                    snapshot.currency,
                    style: AppTypography.bodyMd.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      snapshot.amount,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.headlineLg.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.numericKeypad.fontFeatures,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (snapshot.progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.pill),
                child: LinearProgressIndicator(
                  value: snapshot.progress,
                  minHeight: 6,
                  color: status,
                  backgroundColor: status.withValues(alpha: 0.18),
                ),
              ),
            ],
            if (_rich && snapshot.splitLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                snapshot.splitLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Same hex values as AppColors' status colours and as the native
  /// widget's status_safe/etc. resources — one status, one colour, three
  /// places it has to be named.
  static Color _statusColor(AppColors c, String status) => switch (status) {
    'warning' => c.statusWarning,
    'danger' => c.statusDanger,
    'overdraft' => c.statusOverdraft,
    _ => c.statusSafe,
  };
}