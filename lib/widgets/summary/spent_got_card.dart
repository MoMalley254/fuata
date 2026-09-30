import 'package:flutter/material.dart';

import '../../domain/logic/summary.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'summary_card.dart';

/// "Spent vs Got" as a simple two-bar comparison (ui-design-brief.md
/// 7.11). One idea: which is bigger. Each bar is labelled with its
/// amount, so the meaning never rests on colour alone.
class SpentGotCard extends StatelessWidget {
  const SpentGotCard({
    super.key,
    required this.spentMinor,
    required this.gotMinor,
    required this.currencyCode,
  });

  final int spentMinor;
  final int gotMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final biggest = spentMinor > gotMinor ? spentMinor : gotMinor;
    double share(int v) => biggest <= 0 ? 0 : v / biggest;

    return SummaryCard(
      title: 'Spent and got',
      child: Column(
        children: [
          _BarRow(
            label: 'Spent',
            amount: friendlyMoney(spentMinor, currencyCode),
            fraction: share(spentMinor),
            color: c.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          _BarRow(
            label: 'Got',
            amount: friendlyMoney(gotMinor, currencyCode),
            fraction: share(gotMinor),
            color: c.statusSafe,
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String amount;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
            ),
            Text(
              amount,
              style: AppTypography.labelLg.copyWith(color: c.onSurface),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          minHeight: 12,
          borderRadius: BorderRadius.circular(AppSpacing.pill),
          backgroundColor: c.surfaceContainer,
          color: color,
        ),
      ],
    );
  }
}
