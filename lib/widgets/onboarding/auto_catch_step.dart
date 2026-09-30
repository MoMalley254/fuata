import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'step_frame.dart';

/// Step 5 — auto-catch (ui-design-brief.md 7.1): a plain explainer of
/// reading bank and mobile-money notifications, in three bullets. "Turn on"
/// finishes onboarding and lands on the Auto-Catch screen, where access and
/// the apps to watch are actually chosen.
class AutoCatchStep extends StatelessWidget {
  const AutoCatchStep({
    super.key,
    required this.onTurnOn,
    required this.onLater,
    this.busy = false,
  });

  final VoidCallback onTurnOn;
  final VoidCallback onLater;

  /// True while the final save is running, so a double tap can't finish
  /// twice.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return StepFrame(
      title: 'Catch payments for you',
      subtitle:
          'Fuata can turn a bank or mobile-money notification into a '
          'transaction for you to check.',
      primaryLabel: 'Turn on',
      onPrimary: busy ? null : onTurnOn,
      skipLabel: 'Set it up later',
      onSkip: busy ? () {} : onLater,
      child: const Column(
        children: [
          _Point(
            icon: Icons.visibility_outlined,
            title: 'What it reads',
            text:
                'Only notifications from the apps you pick, like your '
                'messages app or a bank app.',
          ),
          SizedBox(height: AppSpacing.md),
          _Point(
            icon: Icons.block_rounded,
            title: 'What it ignores',
            text:
                'Everything else. Other notifications are dropped the '
                'moment they arrive.',
          ),
          SizedBox(height: AppSpacing.md),
          _Point(
            icon: Icons.phone_android_rounded,
            title: 'Where it stays',
            text: 'On this phone. Nothing is ever sent anywhere.',
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: c.primary.withValues(alpha: 0.12),
          child: Icon(icon, size: 20, color: c.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelLg.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                text,
                style: AppTypography.bodyMd.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
