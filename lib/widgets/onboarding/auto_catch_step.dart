import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'step_frame.dart';

/// Step 6 — auto-catch (F16): what the *next* screen will actually do.
///
/// This is the most important explainer in the flow: the person has just
/// said "yes, show me how" and is about to be dropped into Android's
/// notification-access list, which is one of the most alarming screens in
/// the OS. The copy says what will happen on each tap, then what Fuata
/// does with the access, then what happens if they'd rather not grant it
/// at all.
///
/// The primary button is "Show me how", not "Turn on": this step does not
/// turn anything on — it finishes onboarding and opens Auto-Catch, where
/// access and the apps to watch are chosen.
class AutoCatchStep extends StatelessWidget {
  const AutoCatchStep({
    super.key,
    required this.onTurnOn,
    required this.onLater,
    this.busy = false,
  });

  final VoidCallback onTurnOn;
  final VoidCallback onLater;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StepFrame(
      title: 'One last thing: catching payments for you',
      subtitle: "Here's how it goes.",
      primaryLabel: 'Show me how',
      onPrimary: busy ? null : onTurnOn,
      skipLabel: 'Set it up later',
      onSkip: busy ? () {} : onLater,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NumberedStep(
            number: 1,
            title: 'Tap "Show me how".',
            text: 'We finish setup and open the Auto-catch page.',
          ),
          const _NumberedStep(
            number: 2,
            title: 'Tap "Turn on access".',
            text: "That opens Android's Notification access list.",
          ),
          const _NumberedStep(
            number: 3,
            title: 'Find Fuata and switch it on.',
            text: "Android will show a warning. That's normal — we'll "
                'explain it before you go.',
          ),
          const _NumberedStep(
            number: 4,
            title: 'Come back to Fuata',
            text: 'and pick which apps to watch: your messages app, '
                'M-PESA, your bank.',
            last: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: c.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'What Fuata does with it',
            style: AppTypography.labelLg.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _Point(
            icon: Icons.visibility_outlined,
            title: 'What it reads',
            text: 'Only notifications from the apps you pick, like your '
                'messages app or a bank app.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _Point(
            icon: Icons.block_rounded,
            title: 'What it ignores',
            text: "Anything that doesn't look like a payment. Chats, "
                'one-time codes and everything else are dropped the moment '
                'they arrive.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _Point(
            icon: Icons.phone_android_rounded,
            title: 'Where it stays',
            text: 'On this phone. Nothing is ever sent anywhere.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What if I say no?",
                  style: AppTypography.labelLg.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Nothing breaks. You can add payments by hand or share a '
                      'message to Fuata, and turn this on any time in Settings > '
                      'Auto-catch.',
                  style: AppTypography.bodySm
                      .copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.text,
    this.last = false,
  });

  final int number;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: AppTypography.labelMd.copyWith(color: c.primary),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: c.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
              child: RichText(
                text: TextSpan(
                  style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
                  children: [
                    TextSpan(
                      text: '$title ',
                      style: AppTypography.bodyMd.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: text),
                  ],
                ),
              ),
            ),
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
                style: AppTypography.bodyMd
                    .copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}