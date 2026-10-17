import 'package:flutter/material.dart';

import '../../domain/logic/onboarding.dart';
import '../../domain/models/money.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import 'step_frame.dart';

/// Step 3 — an optional daily limit (ui-design-brief.md 7.1): a big number
/// with a stepper, and a clear way out.
class LimitStep extends StatelessWidget {
  const LimitStep({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSet,
    required this.onSkip,
    required this.currencyCode,
  });

  /// Whole shillings.
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onSet;
  final VoidCallback onSkip;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final symbol = currencySymbol(currencyCode);
    return StepFrame(
      title: 'A daily limit?',
      subtitle:
          'Optional. Home will show how much is left today, and warn you before '
          'you run out. Fuata never stops you spending — it just tells you '
          'early. You can change this any time in Settings > Limits & alerts.',
      primaryLabel: 'Set my daily limit',
      onPrimary: onSet,
      skipLabel: "Skip, I'll decide later",
      onSkip: onSkip,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadiusHero),
              border: Border.all(
                color: c.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(
                      icon: Icons.remove_rounded,
                      label: 'Less',
                      onTap: value <= LimitStepper.min
                          ? null
                          : () => onChanged(LimitStepper.down(value)),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$symbol${LimitStepper.format(value, currencyCode)}',
                          style: AppTypography.displayHero.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ),
                    ),
                    _RoundButton(
                      icon: Icons.add_rounded,
                      label: 'More',
                      onTap: value >= LimitStepper.max
                          ? null
                          : () => onChanged(LimitStepper.up(value)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'per day · resets at midnight',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in LimitStepper.presets)
                AppChoiceChip(
                  label: LimitStepper.format(p, currencyCode),
                  selected: value == p,
                  onTap: () => onChanged(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: onTap == null
            ? c.surfaceContainer
            : c.primary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: AppSpacing.minTouch,
            height: AppSpacing.minTouch,
            child: Icon(
              icon,
              color: onTap == null ? c.onSurfaceTertiary : c.primary,
            ),
          ),
        ),
      ),
    );
  }
}
