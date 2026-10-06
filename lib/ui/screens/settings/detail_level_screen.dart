import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/settings.dart';
import '../../../widgets/app_chips.dart';
import '../../../widgets/personalization/detail_level_example.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';


/// Detail level (issue #79, finding F3): Simple / Balanced / Detailed,
/// with the live example row. Its own screen now.
class DetailLevelScreen extends ConsumerWidget {
  const DetailLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detail level')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Applies to Activity and transaction detail.',
              style: AppTypography.bodySm.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'How much detail?',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: DetailLevel.values.map((lvl) {
                    return AppChoiceChip(
                      label: lvl.label,
                      selected: settings.detailLevel == lvl,
                      onTap: () => update((s) => s.copyWith(detailLevel: lvl)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  settings.detailLevel.description,
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DetailLevelExample(level: settings.detailLevel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}