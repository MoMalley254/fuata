import 'package:flutter/material.dart';
import 'package:fuata/widgets/summary/summary_card.dart';

import '../../domain/logic/summary.dart';
import '../../domain/models/category.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// "Paid on" — spending grouped by category, ranked biggest first
/// (issue #83). Rows for a category that has since been archived show
/// the name with "(archived)" so the history still reads cleanly.
class CategorySplitCard extends StatelessWidget {
  const CategorySplitCard({super.key,
    required this.shares,
    required this.allCategories,
    required this.currencyCode,
  });

  final List<CategoryTotal> shares;
  final List<Category> allCategories;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in allCategories) c.id: c};
    return SummaryCard(
      title: 'Paid on',
      child: Column(
        children: [
          for (final s in shares) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    byId[s.categoryId]?.emoji ?? '🏷️',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      byId[s.categoryId] == null
                          ? 'Unknown'
                          : byId[s.categoryId]!.archived
                          ? '${byId[s.categoryId]!.name} (archived)'
                          : byId[s.categoryId]!.name,
                      style: AppTypography.bodyLg
                          .copyWith(color: context.colors.onSurface),
                    ),
                  ),
                  Text(
                    friendlyMoney(s.minor, currencyCode),
                    style: AppTypography.labelLg
                        .copyWith(color: context.colors.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}