import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// A working, tappable action row — same bordered-card family as
/// ComingSoonRow (icon, title, subtitle) but with a primary-tinted
/// border and a trailing chevron so it reads as "this does something".
///
/// First used for the #18 spike's "open notification access settings"
/// button; stays after #22 lands, replacing that ComingSoonRow rather
/// than sitting alongside it.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
            border: Border.all(color: c.primary.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
                    Text(subtitle,
                        style: AppTypography.bodySm
                            .copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}