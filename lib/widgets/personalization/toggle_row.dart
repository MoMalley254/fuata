import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// Boolean setting row — same bordered-card look as ComingSoonRow so
/// working toggles and "coming soon" rows read as one family, with a
/// live Switch instead of a static chevron.
class ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;

  /// Null renders the row with the switch disabled — used for a toggle
  /// that is only meaningful once another one is on (e.g. biometric
  /// unlock before app lock itself is enabled).
  final ValueChanged<bool>? onChanged;
  const ToggleRow({super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
                Text(subtitle, style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          // No explicit colour override: Material 3's Switch already
          // takes its active colour from ColorScheme.primary, which
          // AppTheme derives from this same accent colour.
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}