import 'package:flutter/material.dart';

import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

/// A row flagging a setting or feature that isn't built yet, with the
/// issue that will build it — so a not-yet-done part of the app is
/// visibly named rather than silently missing. First written as a
/// private widget inside unit_detail_screen.dart (#11); shared here so
/// the Me screen (#12) doesn't duplicate it for its own several rows
/// (limits, banner, message reading, categories).
class ComingSoonRow extends StatelessWidget {
  const ComingSoonRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
                    Text(subtitle, style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
