import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/category.dart';
import '../../../widgets/personalization/educational_empty_state.dart';
import '../../../widgets/personalization/label.dart';
import '../../../widgets/sheets/category_sheet.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Settings > Categories (issue #83, finding F19): rename, recolour, add,
/// archive. Same shape as the Archived units screen — a list of rows with
/// an overflow menu that carries the archive action.
class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Category cat) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategorySheet(existing: cat),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategorySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => Center(child: Text('Something went wrong: $e')),
          data: (categories) {
            final active = categories.where((c) => !c.archived).toList();
            final archived = categories.where((c) => c.archived).toList();
            if (categories.isEmpty) {
              return EducationalEmptyState(
                emoji: '🏷️',
                headline: 'No categories yet',
                description:
                'Categories tell you where money went at a glance — Food, '
                    'Transport, Rent — without having to remember the shop name.',
                primaryLabel: 'Add a category',
                onPrimary: () => _add(context, ref),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'Categories are what you spent on, not who you paid. Tap one '
                      'to rename or recolour it; use the ⋮ menu to put one away.',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Label('In use'),
                const SizedBox(height: AppSpacing.sm),
                for (final cat in active) ...[
                  _CategoryRow(
                    category: cat,
                    onTap: () => _edit(context, ref, cat),
                    onArchive: () => ref
                        .read(categoryRepositoryProvider)
                        .archiveCategory(cat.id),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Label('Put away'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final cat in archived) ...[
                    _CategoryRow(
                      category: cat,
                      onTap: () => _edit(context, ref, cat),
                      onArchive: () => ref
                          .read(categoryRepositoryProvider)
                          .unarchiveCategory(cat.id),
                      archived: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onTap,
    required this.onArchive,
    this.archived = false,
  });

  final Category category;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(category.emoji,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  category.name,
                  style: AppTypography.bodyLg.copyWith(
                    color: archived ? c.onSurfaceVariant : c.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: archived ? 'Bring back' : 'Put away',
                icon: Icon(
                  archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: c.onSurfaceVariant,
                ),
                onPressed: onArchive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

