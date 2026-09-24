
import 'package:flutter/material.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class EmptyActivity extends StatelessWidget {
  const EmptyActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗂️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nothing here yet.',
              style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}