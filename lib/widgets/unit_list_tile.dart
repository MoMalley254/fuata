import 'package:flutter/material.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:fuata/ui/theme/app_spacing.dart';
import 'package:intl/intl.dart';

import '../ui/theme/app_typography.dart';

/// Vertical unit row for My money (ui-design-brief.md section 7.5):
/// "Cards for each unit with icon, name, amount, and a small 'last
/// updated' or 'checked' hint." Distinct from the horizontal UnitCard
/// used on Home — different layout, same accent-colour convention.
class UnitListTile extends StatelessWidget {
  final String emoji;
  final Color color;
  final String name;
  final String balanceText;
  final DateTime? lastVerifiedAt;
  final bool hideAmount;
  final VoidCallback? onTap;

  const UnitListTile({
    super.key,
    required this.emoji,
    required this.color,
    required this.name,
    required this.balanceText,
    this.lastVerifiedAt,
    this.hideAmount = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c= context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.bodyLg.copyWith(color: c.onSurface)),
                    Text(
                      lastVerifiedAt == null
                          ? 'Not checked yet'
                          : 'Checked ${DateFormat('d MMM').format(lastVerifiedAt!)}',
                      style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                hideAmount ? '••••' : balanceText,
                style: AppTypography.headlineSm.copyWith(
                  color: c.onSurface,
                  fontFeatures: AppTypography.numericKeypad.fontFeatures,
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
