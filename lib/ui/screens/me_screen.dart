import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/capture_providers.dart';
import 'package:fuata/ui/screens/auto_catch_screen.dart';
import 'package:fuata/ui/screens/review_inbox_screen.dart';
import 'package:fuata/ui/screens/rule_builder_screen.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../domain/models/settings.dart';
import '../../widgets/coming_soon_row.dart';
import '../../widgets/personalization/action_row.dart';
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
import 'banner_setup_screen.dart';
import 'limits_screen.dart';

/// Me: settings and personalisation (ui-design-brief.md section 7.12,
/// US-13/US-14/US-16). Every control here writes straight through
/// `settingsRepositoryProvider` — same UI-first shape as the rest of the
/// app (screens depend on the repository interface; today that's
/// `MockSettingsRepository`, an in-memory store, same as units/
/// transactions/limits until #13).
///
/// Limits & alerts and Banner each get their own dedicated screens in
/// later issues (#15/#17, #16/#17) — shown here as `ComingSoonRow`s that
/// link out, rather than half-built here. Message reading is live as of
/// #20 (rules), #21 (share/paste capture + review inbox) and #22
/// (Auto-catch: notification access + allowed apps).
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final pendingCount = ref.watch(pendingTransactionsProvider).length;
    final watchedApps = ref.watch(allowedPackagesProvider).length;
    final dailyLimit = (ref.watch(limitsProvider).value ?? const <LimitRule>[])
        .where((l) =>
    l.scope == LimitScope.overall &&
        l.period == LimitPeriod.day &&
        l.enabled)
        .firstOrNull;

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
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
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DetailLevelExample(level: settings.detailLevel),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Limits, banner and messages',
              children: [
                ActionRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Auto-catch',
                  subtitle: watchedApps == 0
                      ? 'Off — pick the apps Fuata may read messages from'
                      : watchedApps == 1
                      ? 'Watching 1 app'
                      : 'Watching $watchedApps apps',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AutoCatchScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.inbox_rounded,
                  title: 'Caught from your messages',
                  subtitle: pendingCount == 0
                      ? 'Nothing waiting for your check'
                      : '$pendingCount waiting for your check',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReviewInboxScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Message reading rules',
                  subtitle:
                  'Teach Fuata to read a bank or mobile-money message',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RuleBuilderScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.speed_rounded,
                  title: 'Limits & alerts',
                  subtitle: dailyLimit == null
                      ? 'Set how much you can spend each day, week or month'
                      : 'Daily limit: ${Money(dailyLimit.amountMinor, dailyLimit.currencyCode).format()}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LimitsScreen()),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Banner',
                  subtitle: settings.bannerEnabled
                      ? 'On — choose what it shows'
                      : 'Off — choose what the notification banner shows',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BannerSetupScreen()),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                ComingSoonRow(
                  icon: Icons.sell_outlined,
                  title: 'Categories',
                  subtitle:
                  'Rename or add category names and icons — coming soon',
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
                      leading: Icon(
                        mode.icon,
                        size: 16,
                        color: settings.themeMode == mode
                            ? c.primary
                            : c.onSurfaceVariant,
                      ),
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