import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/limit_rule.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/settings.dart';
import '../../../routing/routes.dart';
import '../../../widgets/personalization/action_row.dart';
import '../../providers/app_providers.dart';
import '../../providers/capture_providers.dart';
import '../../theme/app_spacing.dart';

/// Settings (issue #79, finding F3): what used to be the Me tab, minus
/// the profile — a list of rows, each opening its own screen, rather than
/// cards with controls inline.
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
            // How the app looks and reads.
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

            // Reading and catching messages, and the limits they feed.
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
              icon: Icons.speed_rounded,
              title: 'Limits & alerts',
              subtitle: dailyLimit == null
                  ? 'Set how much you can spend each day, week or month'
                  : 'Daily limit: ${Money(dailyLimit.amountMinor, dailyLimit.currencyCode).format()}',
              onTap: () => context.push(Routes.limitsPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActionRow(
              icon: Icons.notifications_outlined,
              title: 'Banner',
              subtitle: settings.bannerEnabled
                  ? 'On — choose what it shows'
                  : 'Off — choose what the notification banner shows',
              onTap: () => context.push(Routes.bannerPath),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Data that isn't a setting yet, and where it lives.
            ActionRow(
              icon: Icons.sell_outlined,
              title: 'Categories',
              subtitle: 'Rename, add or put away the categories you use',
              onTap: () => context.push(Routes.settingsCategoriesPath),
            ),
            const SizedBox(height: AppSpacing.sm),
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
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}