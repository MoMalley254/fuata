import 'package:flutter/material.dart';

import '../domain/models/category.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';
import 'app_chips.dart';

/// The category picker under the "who" field (issue #83). Reuses the
/// existing pill chip so it sits flush with the unit chips above it.
class CategoryChipRow extends StatelessWidget {
  const CategoryChipRow({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What for?',
          style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final cat in categories)
              AppChoiceChip(
                label: '${cat.emoji} ${cat.name}',
                selected: selectedId == cat.id,
                // Tapping the selected chip again clears the choice — a
                // transaction with no category is a legitimate state, and
                // the sheet should not force one.
                onTap: () => onSelected(
                  selectedId == cat.id ? null : cat.id,
                ),
              ),
          ],
        ),
      ],
    );
  }
}