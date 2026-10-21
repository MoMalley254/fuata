import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../contact_widget.dart';
import 'step_frame.dart';

/// Step 1 — welcome (F12). Nothing to fill in, nothing to decide: the
/// first screen the person ever sees is a friendly introduction, not a
/// form. The name and accent come next, on their own step, where the
/// person already knows what the app is.
class HelloStep extends StatelessWidget {
  const HelloStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StepFrame(
      hero: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text('🐷', style: TextStyle(fontSize: 48)),
      ),
      title: "Hi, I'm Fuata 👋",
      subtitle:
          'I help you keep track of your money without the stress: what you '
          "have, what you've spent, and what's left for today. Everything "
          'stays on this phone.',
      primaryLabel: "Let's get started",
      onPrimary: onContinue,
      // No skip: this screen has nothing to skip.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LittleLine(
            icon: Icons.schedule_rounded,
            text: 'Takes about 2 minutes',
          ),
          SizedBox(height: AppSpacing.sm),
          _LittleLine(
            icon: Icons.skip_next_rounded,
            text: 'Skip anything you like',
          ),
          SizedBox(height: AppSpacing.sm),
          _LittleLine(
            icon: Icons.tune_rounded,
            text: 'You can change it all later',
          ),
          SizedBox(height: AppSpacing.md),
          Contact(),
        ],
      ),
    );
  }
}

class _LittleLine extends StatelessWidget {
  const _LittleLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

