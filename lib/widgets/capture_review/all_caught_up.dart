import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class AllCaughtUp extends StatelessWidget {
  const AllCaughtUp({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎣', style: TextStyle(fontSize: 40)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'All caught up.',
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Share or paste a bank message and it will wait here for '
                  'your check.',
              textAlign: TextAlign.center,
              style:
              AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
