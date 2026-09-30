import 'package:flutter/material.dart';

import '../../domain/logic/banner_content.dart';
import '../../domain/logic/onboarding.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../banner/banner_preview.dart';
import 'step_frame.dart';

/// Step 4 — the ongoing banner (ui-design-brief.md 7.1): a live preview
/// built by the same BannerContent the real notification uses, from what
/// the person has entered so far.
class BannerStep extends StatelessWidget {
  const BannerStep({
    super.key,
    required this.draft,
    required this.onYes,
    required this.onNotNow,
  });

  final OnboardingDraft draft;
  final VoidCallback onYes;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Their own units if they added any; otherwise two made-up ones, so
    // the preview still shows what the banner looks like.
    final now = DateTime.now();
    final units = draft.units.isNotEmpty
        ? draft.units
        : [
            MoneyUnit(
              id: 'sample_cash',
              name: 'Cash',
              kind: UnitKind.cash,
              currencyCode: OnboardingDraft.currencyCode,
              iconEmoji: '💵',
              color: c.unitCash,
              openingBalanceMinor: 76000,
              sortOrder: 0,
              createdAt: now,
            ),
            MoneyUnit(
              id: 'sample_mobile',
              name: 'Mobile money',
              kind: UnitKind.mobileMoney,
              currencyCode: OnboardingDraft.currencyCode,
              iconEmoji: '📱',
              color: c.unitMobileMoney,
              openingBalanceMinor: 234000,
              sortOrder: 1,
              createdAt: now,
            ),
          ];

    final limitMinor = draft.dailyLimitMinor;
    final limit = limitMinor == null
        ? null
        : LimitRule(
            id: 'preview',
            scope: LimitScope.overall,
            period: LimitPeriod.day,
            amountMinor: limitMinor,
            currencyCode: OnboardingDraft.currencyCode,
          );
    // A comfortable quarter of the limit, or a round example amount.
    final spent = limit == null ? 35000 : (limit.amountMinor * 0.25).round();

    final content = BannerContent.build(
      status: limit?.statusFor(spent) ?? SpendStatus.safe,
      spentToday: spent,
      dailyLimit: limit,
      units: units,
      balanceByUnit: {for (final u in units) u.id: u.openingBalanceMinor},
      headline: BannerHeadline.leftToday,
      selectedUnitIds: const {},
      showProgress: true,
      showQuickAdd: true,
      redacted: false,
    );

    return StepFrame(
      title: 'Your banner',
      subtitle: 'Show this in your notifications?',
      primaryLabel: 'Yes, show it',
      onPrimary: onYes,
      skipLabel: 'Not now',
      onSkip: onNotNow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BannerPreview(content: content),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Shown with example spending. You can change what it shows, or '
            'turn it off, in Me.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
