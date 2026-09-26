import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// "A message will match if it looks like this": shows the person the
/// shape of message the rule they just built will accept — the sample
/// with each labeled span replaced by `xxxx(FieldName)`, and anything
/// after the last label dropped (see [describePattern]).
///
/// Sits directly under "Here's what I found" in the rule builder, so the
/// two read as one answer: this is what we'd extract from *this* sample,
/// and this is what a *future* message needs to look like for us to try.
class PatternPreviewCard extends StatelessWidget {
  final String description;
  const PatternPreviewCard({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A message will match if it looks like this',
            style: AppTypography.labelSm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodySm.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Only the parts shown here matter — anything after the last '
                'xxxx(...) is ignored.',
            style: AppTypography.labelSm.copyWith(color: c.onSurfaceTertiary),
          ),
        ],
      ),
    );
  }
}