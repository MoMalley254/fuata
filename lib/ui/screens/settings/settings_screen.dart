import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/widgets/contact_widget.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/limit_rule.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/outing.dart';
import '../../../domain/models/settings.dart';
import '../../../routing/routes.dart';
import '../../../widgets/personalization/action_row.dart';
import '../../providers/app_providers.dart';
import '../../providers/capture_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Settings (issue #79, finding F3): what used to be the Me tab, minus
/// the profile — a list of rows, each opening its own screen, rather than
/// cards with controls inline.
///
/// Rows are grouped into labelled sections (Money, Catching messages,
/// Notifications, How it looks, Privacy & security) so the screen can be
/// *scanned* instead of scrolled top-to-bottom. Groups are made visible
/// by a small-caps header above them and by a wider gap between groups
/// than within them; the ActionRows themselves are unchanged, so nothing
/// else that uses ActionRow is affected.
///
/// "Profile" is deliberately not a row here. It's reached from the avatar
/// on Today, which is where a person looks for their own name and colour;
/// Settings is about the app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final pendingCount = ref.watch(pendingTransactionsProvider).length;
    final watchedApps = ref.watch(allowedPackagesProvider).length;
    final dailyLimit = (ref.watch(limitsProvider).value ?? const <LimitRule>[])
        .where(
          (l) =>
      l.scope == LimitScope.overall &&
          l.period == LimitPeriod.day &&
          l.enabled,
    )
        .firstOrNull;
    final outingsCount =
        (ref.watch(outingsProvider).value ?? const <Outing>[]).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            // ---- Money -------------------------------------------------
            const _SectionHeader('Money'),
            ActionRow(
              icon: Icons.speed_rounded,
              title: 'Limits & alerts',
              subtitle: dailyLimit == null
                  ? 'Set how much you can spend each day, week or month'
                  : 'Daily limit: ${Money(dailyLimit.amountMinor, dailyLimit.currencyCode).format()}',
              onTap: () => context.push(Routes.limitsPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.flight_takeoff_rounded,
              title: 'Outings',
              subtitle: outingsCount == 0
                  ? 'A temporary budget for a trip or a weekend'
                  : outingsCount == 1
                  ? '1 outing'
                  : '$outingsCount outings',
              onTap: () => context.push(Routes.outingsPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.sell_outlined,
              title: 'Categories',
              subtitle: 'Rename, add or put away the categories you use',
              onTap: () => context.push(Routes.settingsCategoriesPath),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---- Catching messages ------------------------------------
            const _SectionHeader('Catching messages'),
            ActionRow(
              icon: Icons.notifications_active_outlined,
              title: 'Auto-catch',
              subtitle: watchedApps == 0
                  ? 'Off — pick the apps Fuata may read messages from'
                  : watchedApps == 1
                  ? 'Watching 1 app'
                  : 'Watching $watchedApps apps',
              onTap: () => context.push(Routes.autoCatchPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.inbox_rounded,
              title: 'Caught from your messages',
              subtitle: pendingCount == 0
                  ? 'Nothing waiting for your check'
                  : '$pendingCount waiting for your check',
              onTap: () => context.push(Routes.inboxPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.mark_email_read_outlined,
              title: 'Message reading rules',
              subtitle: 'Teach Fuata to read a bank or mobile-money message',
              onTap: () => context.push(Routes.ruleBuilderNewPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.inventory_2_outlined,
              title: 'Message reading packs',
              subtitle: 'Ready-made rules for M-PESA, Airtel and banks',
              onTap: () => context.push(Routes.templatePacksPath),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---- Notifications ---------------------------------------
            const _SectionHeader('Notifications'),
            ActionRow(
              icon: Icons.notifications_outlined,
              title: 'Banner',
              subtitle: settings.bannerEnabled
                  ? 'On — choose what it shows'
                  : 'Off — choose what the notification banner shows',
              onTap: () => context.push(Routes.bannerPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.schedule_send_outlined,
              title: 'Summary notifications',
              subtitle: settings.summaryNotificationsEnabled
                  ? 'On — daily, weekly or monthly reminders'
                  : 'Off — a periodic nudge about how your money went',
              onTap: () => context.push(Routes.settingsSummaryNotificationsPath),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---- How it looks ----------------------------------------
            const _SectionHeader('How it looks'),
            ActionRow(
              icon: Icons.home_outlined,
              title: 'Home',
              subtitle: 'Headline number, sections',
              onTap: () => context.push(Routes.settingsHomePath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.list_alt_rounded,
              title: 'Detail level',
              subtitle: settings.detailLevel.label,
              onTap: () => context.push(Routes.settingsDetailPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: settings.themeMode.label,
              onTap: () => context.push(Routes.settingsAppearancePath),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---- Privacy & security ----------------------------------
            const _SectionHeader('Privacy & security'),
            ActionRow(
              icon: Icons.fingerprint_rounded,
              title: 'Security',
              subtitle: settings.appLockEnabled
                  ? 'App lock is on'
                  : 'App lock is off — anyone with the phone can open Fuata',
              onTap: () => context.push(Routes.settingsSecurityPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy & data',
              subtitle: 'Lock-screen redaction, back up & restore',
              onTap: () => context.push(Routes.settingsPrivacyPath),
            ),
            const SizedBox(height: AppSpacing.md,),
            Contact(),
          ],
        ),
      ),
    );
  }
}

/// Small-caps section header. Sits above a group of ActionRows; the
/// wider gap after each group (`AppSpacing.lg`) is what separates the
/// groups visually — the rows themselves keep their own border, so a
/// section reads as a run of cards under a shared label rather than one
/// big box (which would double up the ActionRow border and look noisy).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: c.onSurfaceVariant,
          letterSpacing: 0.08,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}