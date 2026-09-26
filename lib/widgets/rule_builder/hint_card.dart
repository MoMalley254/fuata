import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class HintCard extends StatelessWidget {
  final AppColors c;
  final String message;
  const HintCard({super.key, required this.c, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Text(
        message,
        style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
      ),
    );
  }
}
