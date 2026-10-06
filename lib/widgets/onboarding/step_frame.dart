import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// The shared layout of every onboarding step (ui-design-brief.md 7.1):
/// a title and one friendly line, the step's own content, then one primary
/// button and a quiet skip link. Nothing here knows which step it is.
class StepFrame extends StatelessWidget {
  const StepFrame({
    super.key,
    this.hero,
    required this.title,
    this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.skipLabel,
    this.onSkip,
  });

  final Widget? hero;
  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Every onboarding step can be skipped except the welcome (F12); when
  /// [skipLabel] is null the skip link is hidden.
  final String? skipLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          // F13: short content sits around 35–40% down the screen instead
          // of leaving a hole above the buttons; long content still
          // scrolls. Spacer(flex: 1) above and Spacer(flex: 2) below split
          // the free space 1:2, which is what puts the content there.
          //
          // IntrinsicHeight gives the Column a bounded height so Spacer
          // works inside a SingleChildScrollView (which would otherwise
          // give it unbounded height, and Spacer would throw). This is the
          // standard "footer in a scrollable" pattern and it stays
          // keyboard-safe.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.md,
                AppSpacing.margin,
                AppSpacing.md,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 1),
                      if (hero != null) ...[
                        hero!,
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        title,
                        style: AppTypography.headlineLg.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle!,
                          style: AppTypography.bodyLg.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      child,
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              if (skipLabel != null && onSkip != null) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(onPressed: onSkip, child: Text(skipLabel!)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One dot per step; the current one stretches into a pill.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? c.primary
                  : c.outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSpacing.pill),
            ),
          ),
      ],
    );
  }
}

/// A small tinted note, e.g. "We never ask for account or card numbers."
class ReassuranceNote extends StatelessWidget {
  const ReassuranceNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
