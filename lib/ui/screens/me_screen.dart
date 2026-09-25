import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/settings.dart';
import '../../widgets/coming_soon_row.dart';
import '../../widgets/personalization/detail_level_example.dart';
import '../../widgets/personalization/label.dart';
import '../../widgets/personalization/privayc_card.dart';
import '../../widgets/personalization/profile_block.dart';
import '../../widgets/personalization/section_card.dart';
import '../../widgets/personalization/toggle_row.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../widgets/app_chips.dart';

/// Me: settings and personalisation (ui-design-brief.md section 7.12,
/// US-13/US-14/US-16). Every control here writes straight through
/// `settingsRepositoryProvider` — same UI-first shape as the rest of the
/// app (screens depend on the repository interface; today that's
/// `MockSettingsRepository`, an in-memory store, same as units/
/// transactions/limits until #13).
///
/// Limits & alerts, Banner, and Message reading each get their own
/// dedicated screens in later issues (#15/#17, #16/#17, #19-#22) — shown
/// here as `ComingSoonRow`s that link out, rather than half-built here.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.xl,
          ),
          children: [
            ProfileBlock(settings: settings, onChanged: update),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Home',
              children: [
                Label('Headline number'),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.md),
                Label('Sections'),
                const SizedBox(height: AppSpacing.xs),
                ...HomeSection.values.map((section) {
                  final on = settings.homeSections.contains(section);
                  return ToggleRow(
                    title: section.label,
                    subtitle: section.description,
                    value: on,
                    onChanged: (v) => update((s) {
                      final next = Set<HomeSection>.from(s.homeSections);
                      if (v) {
                        next.add(section);
                      } else {
                        next.remove(section);
                      }
                      return s.copyWith(homeSections: next);
                    }),
                  );
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Detail level',
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
                  style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                DetailLevelExample(level: settings.detailLevel),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Limits, banner and messages',
              children: const [
                ComingSoonRow(
                  icon: Icons.speed_rounded,
                  title: 'Limits & alerts',
                  subtitle: 'Daily, weekly and monthly limits, plus nudges — coming in #15/#17',
                ),
                SizedBox(height: AppSpacing.sm),
                ComingSoonRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Banner',
                  subtitle: 'Choose what the notification banner shows — coming in #16/#17',
                ),
                SizedBox(height: AppSpacing.sm),
                ComingSoonRow(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Message reading',
                  subtitle: 'Rules and allowed apps for auto-catch — coming in #19-#22',
                ),
                SizedBox(height: AppSpacing.sm),
                ComingSoonRow(
                  icon: Icons.sell_outlined,
                  title: 'Categories',
                  subtitle: 'Rename or add category names and icons — coming soon',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Appearance',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: AppThemeMode.values.map((mode) {
                    return AppChoiceChip(
                      label: mode.label,
                      leading: Icon(mode.icon, size: 16, color: settings.themeMode == mode ? c.primary : c.onSurfaceVariant),
                      selected: settings.themeMode == mode,
                      onTap: () => update((s) => s.copyWith(themeMode: mode)),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrivacyCard(settings: settings, onChanged: update),
          ],
        ),
      ),
    );
  }
}









