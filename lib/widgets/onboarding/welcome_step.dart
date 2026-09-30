import 'package:flutter/material.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/label.dart';
import 'step_frame.dart';

/// Step 1 — welcome, name and accent colour (ui-design-brief.md 7.1).
/// The accent applies to the whole app as it is picked, so the person sees
/// the effect straight away.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.nameController,
    required this.accent,
    required this.onAccent,
    required this.onContinue,
    required this.onSkip,
  });

  final TextEditingController nameController;
  final Color accent;
  final ValueChanged<Color> onAccent;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StepFrame(
      title: 'Your money, in one glance.',
      subtitle: 'Everything stays on this phone.',
      primaryLabel: 'Continue',
      onPrimary: onContinue,
      skipLabel: 'Skip for now',
      onSkip: onSkip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('What should we call you?'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onContinue(),
            decoration: const InputDecoration(hintText: 'Your name'),
            style: AppTypography.bodyLg.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Label('Pick a colour'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final swatch in AppAccents.swatches)
                _Swatch(
                  color: swatch,
                  selected: accent.toARGB32() == swatch.toARGB32(),
                  onTap: () => onAccent(swatch),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pill),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? c.onSurface : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
