import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/banner_content.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../domain/models/settings.dart';
import '../../platform/banner.dart';
import '../../platform/notification_capture.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/banner/banner_preview.dart';
import '../../widgets/personalization/section_card.dart';
import '../../widgets/personalization/toggle_row.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Banner setup (issue #17, US-05, ui-design-brief.md 7.9): choose what the
/// notification banner shows, with a live preview at the top.
///
/// Options are saved straight into AppSettings; the banner service (#16)
/// reads the same settings and the same BannerContent.build(), so the
/// preview never disagrees with the real notification.
class BannerSetupScreen extends ConsumerStatefulWidget {
  const BannerSetupScreen({super.key});

  @override
  ConsumerState<BannerSetupScreen> createState() => _BannerSetupScreenState();
}

/// null = "Now" (the person's real numbers); otherwise a made-up day that
/// lands in that status, so all four looks can be checked (brief 7.10).
class _BannerSetupScreenState extends ConsumerState<BannerSetupScreen> {
  SpendStatus? _sample;
  bool _lockScreen = false;

  static const _sampleRatio = {
    SpendStatus.safe: 0.25,
    SpendStatus.warning: 0.8,
    SpendStatus.danger: 0.95,
    SpendStatus.overdraft: 1.1,
  };

  void _update(AppSettings Function(AppSettings) fn) {
    final current = ref.read(currentSettingsProvider);
    ref.read(settingsRepositoryProvider).updateSettings(fn(current));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final s = ref.watch(currentSettingsProvider);
    final home = ref.watch(homeStateProvider).value ?? HomeState.empty;
    final units = home.units.where((u) => !u.archived).toList();

    // --- Numbers the preview uses: real ones, or an illustrative day. ---
    var spent = home.spentToday;
    var limit = home.dailyLimit;
    var status = home.status;
    final sample = _sample;
    if (sample != null) {
      final code = limit?.currencyCode ??
          (units.isEmpty ? 'KES' : units.first.currencyCode);
      final amount =
          limit?.amountMinor ?? Money.parseMajor('2000', code).minor;
      limit = LimitRule(
        id: 'preview',
        scope: LimitScope.overall,
        period: LimitPeriod.day,
        amountMinor: amount,
        currencyCode: code,
      );
      spent = (amount * _sampleRatio[sample]!).round();
      status = limit.statusFor(spent);
    }

    final content = BannerContent.build(
      status: status,
      spentToday: spent,
      dailyLimit: limit,
      units: units,
      balanceByUnit: home.balanceByUnit,
      headline: s.bannerHeadline,
      selectedUnitIds: s.bannerUnitIds,
      showProgress: s.bannerShowProgress,
      showQuickAdd: s.bannerShowQuickAdd,
      redacted: s.amountsHidden || (_lockScreen && s.redactedLockScreenBanner),
    );

    final allUnits = s.bannerUnitIds.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Banner')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.margin, AppSpacing.md, AppSpacing.margin, AppSpacing.xl),
          children: [
            if (s.bannerEnabled)
              FutureBuilder<bool>(
                future: BannerPlatform.instance.areNotificationsEnabled(),
                builder: (context, snap) {
                  final enabled = snap.data ?? true;
                  if (enabled) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: c.statusWarningContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
                        border: Border.all(color: c.statusWarningBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: c.statusWarning, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Android is blocking Fuata's notifications",
                                  style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Turn them on in Android\'s settings to see the banner.',
                                  style: AppTypography.bodySm
                                      .copyWith(color: c.onSurfaceVariant),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextButton(
                                  onPressed: () => openAppNotificationSettings(),
                                  child: const Text('Open settings'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            SectionCard(
              title: 'Preview',
              children: [
                BannerPreview(content: content),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppChoiceChip(
                      label: 'Now',
                      selected: _sample == null,
                      onTap: () => setState(() => _sample = null),
                    ),
                    for (final st in SpendStatus.values)
                      AppChoiceChip(
                        label: '${st.emoji} ${st.label}',
                        selected: _sample == st,
                        onTap: () => setState(() => _sample = st),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    AppChoiceChip(
                      label: 'Unlocked',
                      selected: !_lockScreen,
                      onTap: () => setState(() => _lockScreen = false),
                    ),
                    AppChoiceChip(
                      label: 'Lock screen',
                      selected: _lockScreen,
                      onTap: () => setState(() => _lockScreen = true),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Android limits notification colour, so your status shows as an '
                      'emoji, a progress bar and a coloured icon.',
                  style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Show the banner',
              children: [
                ToggleRow(
                  title: 'Banner in my notifications',
                  subtitle: 'See how you are doing without opening the app.',
                  value: s.bannerEnabled,
                  onChanged: (v) => _update((x) => x.copyWith(bannerEnabled: v)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'The big number',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final h in BannerHeadline.values)
                      AppChoiceChip(
                        label: h.label,
                        selected: s.bannerHeadline == h,
                        onTap: () => _update((x) => x.copyWith(bannerHeadline: h)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Units shown',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppChoiceChip(
                      label: 'All',
                      selected: allUnits,
                      onTap: () =>
                          _update((x) => x.copyWith(bannerUnitIds: <String>{})),
                    ),
                    for (final u in units)
                      AppChoiceChip(
                        label: '${u.iconEmoji} ${u.name}',
                        selected: !allUnits && s.bannerUnitIds.contains(u.id),
                        onTap: () => _update((x) {
                          final next = {...x.bannerUnitIds};
                          if (!next.remove(u.id)) next.add(u.id);
                          // Everything picked, or nothing left: same as "All".
                          final everything = units.every((e) => next.contains(e.id));
                          return x.copyWith(
                            bannerUnitIds: everything ? <String>{} : next,
                          );
                        }),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Details',
              children: [
                ToggleRow(
                  title: 'Progress bar',
                  subtitle: 'How much of today\'s limit is used.',
                  value: s.bannerShowProgress,
                  onChanged: (v) =>
                      _update((x) => x.copyWith(bannerShowProgress: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                ToggleRow(
                  title: '+ Add button',
                  subtitle: 'Add a transaction straight from the banner.',
                  value: s.bannerShowQuickAdd,
                  onChanged: (v) =>
                      _update((x) => x.copyWith(bannerShowQuickAdd: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                ToggleRow(
                  title: 'Hide amounts on the lock screen',
                  subtitle: 'Shows only the status until the phone is unlocked.',
                  value: s.redactedLockScreenBanner,
                  onChanged: (v) =>
                      _update((x) => x.copyWith(redactedLockScreenBanner: v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}