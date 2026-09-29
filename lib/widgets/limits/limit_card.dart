import 'package:flutter/material.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class LimitCard extends StatelessWidget {
  final LimitPeriod period;
  final LimitRule? limit;
  final String currencyCode;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const LimitCard({
    super.key,
    required this.period,
    required this.limit,
    required this.currencyCode,
    required this.onTap,
    required this.onToggle,
  });

  String get _title => switch (period) {
    LimitPeriod.day => 'Daily',
    LimitPeriod.week => 'Weekly',
    LimitPeriod.month => 'Monthly',
  };

  String get _blurb => switch (period) {
    LimitPeriod.day => 'Resets at midnight.',
    LimitPeriod.week => 'Resets each Monday.',
    LimitPeriod.month => 'Resets on the first of the month.',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = limit;
    final subtitle = l == null
        ? 'Not set · $_blurb'
        : '${Money(l.amountMinor, currencyCode).format()} · '
        '${l.enabled ? _blurb.toLowerCase() : 'Paused'}';

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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
            _title,
            style: AppTypography.bodyLg.copyWith(
              color: l == null || !l.enabled
                  ? c.onSurfaceVariant
                  : c.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySm.copyWith(
              color: c.onSurfaceVariant,
            ),
          ),
          ]
                ),
              ),
              Switch.adaptive(
                value: l?.enabled ?? false,
                onChanged: onToggle,
              ),
              Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
