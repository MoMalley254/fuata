import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/custom_accent_swatch.dart';
import '../personalization/label.dart';
import '../sheets/accent_colour_picker_sheet.dart';
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
    required this.currencyCode,
    required this.onCurrencyChanged,
  });

  final TextEditingController nameController;
  final Color accent;
  final ValueChanged<Color> onAccent;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currencyInfo = CurrencyService().findByCode(currencyCode);

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
              CustomAccentSwatch(
                selected: !AppAccents.isPreset(accent),
                size: 44,
                onTap: () async {
                  final picked = await showAccentColorPicker(
                    initial: accent,
                  );
                  if (picked != null) onAccent(picked);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Label('Currency'),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () => showCurrencyPicker(
              context: context,
              showFlag: false,
              onSelect: (Currency picked) => onCurrencyChanged(picked.code),
            ),
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
                border: Border.all(
                  color: c.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currencyInfo == null
                              ? currencyCode
                              : '${currencyInfo.name} (${currencyInfo.code})',
                          style:
                          AppTypography.bodyLg.copyWith(color: c.onSurface),
                        ),
                        Text(
                          'Fuata uses one currency everywhere. '
                              'You can change it later.',
                          style: AppTypography.bodySm
                              .copyWith(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: c.onSurfaceVariant),
                ],
              ),
            ),
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
