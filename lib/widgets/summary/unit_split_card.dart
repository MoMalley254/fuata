import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/summary.dart';
import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'summary_card.dart';

/// Where the spending came from, as one soft stacked bar plus a legend
/// (ui-design-brief.md 7.11). The legend carries every figure, so the
/// bar's colours are decoration, not the only signal.
class UnitSplitCard extends ConsumerWidget {
  const UnitSplitCard({
    super.key,
    required this.shares,
    required this.unitById,
    required this.totalMinor,
    required this.currencyCode,
  });

  final List<UnitTotal> shares;
  final Map<String, MoneyUnit> unitById;
  final int totalMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;
    final c = context.colors;

    // An archived unit is not in the live list but its spending still
    // happened, so it gets a neutral slice instead of vanishing.
    final slices = [
      for (final s in shares)
        (
          name: unitById[s.unitId]?.name ?? 'Archived unit',
          emoji: unitById[s.unitId]?.iconEmoji ?? '📦',
          color: unitById[s.unitId]?.color ?? c.outline,
          minor: s.minor,
        ),
    ];

    return SummaryCard(
      title: 'Paid from',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pill),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final s in slices)
                    Expanded(
                      flex: s.minor > 0 ? s.minor : 1,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        color: s.color,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${s.emoji} ${s.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${friendlyMoney(s.minor, currencyCode, masked: hidden)} · '
                        '${totalMinor <= 0 ? 0 : (s.minor * 100 / totalMinor).round()}%',
                    style: AppTypography.bodySm.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
