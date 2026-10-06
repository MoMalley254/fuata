import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/settings.dart';
import '../../../widgets/app_chips.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../../widgets/personalization/toggle_row.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_spacing.dart';

/// Home options (issue #79, finding F3): the headline number and which
/// sections Home shows. Its own screen now instead of two controls inline
/// on Settings.
class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              title: 'Headline number',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: HomeHeadline.values.map((h) {
                    return AppChoiceChip(
                      label: h.label,
                      selected: settings.homeHeadline == h,
                      onTap: () => update((s) => s.copyWith(homeHeadline: h)),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Sections',
              children: [
                for (final section in HomeSection.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ToggleRow(
                      title: section.label,
                      subtitle: section.description,
                      value: settings.homeSections.contains(section),
                      onChanged: (v) => update((s) {
                        final next = Set<HomeSection>.from(s.homeSections);
                        if (v) {
                          next.add(section);
                        } else {
                          next.remove(section);
                        }
                        return s.copyWith(homeSections: next);
                      }),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}