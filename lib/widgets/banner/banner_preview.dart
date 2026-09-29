import 'package:flutter/material.dart';
import 'package:fuata/domain/logic/banner_content.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_status.dart';
import '../../ui/theme/app_typography.dart';

/// A mock of the Android notification shade showing the banner both
/// collapsed and expanded (ui-design-brief.md 7.9 / 7.10). Purely
/// presentational: everything it shows comes from [BannerContent].
class BannerPreview extends StatelessWidget {
  final BannerContent content;
  const BannerPreview({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Collapsed',
              style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          _Card(content: content, expanded: false),
          const SizedBox(height: AppSpacing.md),
          Text('Expanded',
              style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          _Card(content: content, expanded: true),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final BannerContent content;
  final bool expanded;
  const _Card({required this.content, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = content.status.fg(c);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Android's app row: small accent icon, app name, "now".
          Row(
            children: [
              Icon(content.status.icon, size: 14, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Text('Fuata · now',
                  style: AppTypography.labelSm
                      .copyWith(color: c.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(content.title,
              style: AppTypography.bodyMd.copyWith(
                  color: c.onSurface, fontWeight: FontWeight.w700)),
          if (content.progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.pill),
              child: LinearProgressIndicator(
                value: content.progress,
                minHeight: 6,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.18),
              ),
            ),
          ],
          if (expanded) ...[
            if (content.unitLines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(content.unitLines.join(' · '),
                  style: AppTypography.bodySm
                      .copyWith(color: c.onSurfaceVariant)),
            ],
            if (content.spentLine != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(content.spentLine!,
                  style: AppTypography.bodySm
                      .copyWith(color: c.onSurfaceVariant)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (content.showQuickAdd) ...[
                  _ActionLabel('+ Add', color: c.primary),
                  const SizedBox(width: AppSpacing.md),
                ],
                _ActionLabel('Open', color: c.primary),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text,
      style: AppTypography.labelLg.copyWith(color: color));
}

