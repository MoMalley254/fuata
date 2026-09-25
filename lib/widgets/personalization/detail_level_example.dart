import 'package:flutter/material.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// A small static preview so "Detail level" isn't just three labels —
/// the person can see what each level actually shows before picking one
/// (design brief 7.12: "with live example row"). Mirrors the field
/// choices in transaction_detail_sheet.dart's detailRows, on one
/// representative sample transaction rather than a real one.
class DetailLevelExample extends StatelessWidget {
  final DetailLevel level;
  const DetailLevelExample({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = switch (level) {
      DetailLevel.simple => const ['Java House', 'this afternoon · -350'],
      DetailLevel.balanced => const ['Java House · Mobile money', 'Food · this afternoon · -350'],
      DetailLevel.detailed => const [
        'Java House · Mobile money · Food',
        '21 Sep, 1:12 PM · code QW12ABC3 · -350',
      ],
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('📱', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .asMap()
                  .entries
                  .map((e) => Text(
                e.value,
                style: (e.key == 0 ? AppTypography.bodyMd : AppTypography.bodySm)
                    .copyWith(color: e.key == 0 ? c.onSurface : c.onSurfaceVariant),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}