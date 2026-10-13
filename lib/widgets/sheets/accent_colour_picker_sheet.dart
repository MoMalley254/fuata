import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

Future<Color?> showAccentColorPicker({required Color initial}) async {
  return await SmartDialog.show(
    builder: (_) => AccentColourPickerSheet(initial: initial),
  );
}

class AccentColourPickerSheet extends StatefulWidget {
  final Color initial;
  const AccentColourPickerSheet({super.key, required this.initial});

  @override
  State<AccentColourPickerSheet> createState() => _AccentColourPickerSheetState();
}

class _AccentColourPickerSheetState extends State<AccentColourPickerSheet> {
  late HSLColor _hsl;

  @override
  void initState() {
    super.initState();
    _hsl = HSLColor.fromColor(widget.initial);
  }

  Color get _color => _hsl.toColor();

  String get _hex {
    final argb = _color.toARGB32();
    String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${two((argb >> 16) & 0xFF)}'
        '${two((argb >> 8) & 0xFF)}'
        '${two(argb & 0xFF)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.cardRadiusHero),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: c.outlineVariant,
                      borderRadius: BorderRadius.circular(AppSpacing.pill),
                    ),
                  ),
                ),
                Text(
                  'Pick your colour',
                  style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Drag the sliders. Fuata tints what it needs to, so any '
                      'colour stays readable in light and dark.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Preview(color: _color),

                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _hex,
                    style: AppTypography.bodySm.copyWith(
                      color: c.onSurfaceTertiary,
                      fontFeatures: AppTypography.numericKeypad.fontFeatures,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                _GradientSlider(
                  label: 'Hue',
                  value: _hsl.hue,
                  min: 0,
                  max: 360,
                  colors: [
                    for (final h in const [
                      0.0,
                      60.0,
                      120.0,
                      180.0,
                      240.0,
                      300.0,
                      360.0,
                    ])
                      HSLColor.fromAHSL(1, h, 1, 0.5).toColor(),
                  ],
                  onChanged: (v) => setState(() => _hsl = _hsl.withHue(v)),
                ),
                _GradientSlider(
                  label: 'Saturation',
                  value: _hsl.saturation,
                  min: 0,
                  max: 1,
                  colors: [
                    HSLColor.fromAHSL(1, _hsl.hue, 0, _hsl.lightness).toColor(),
                    HSLColor.fromAHSL(1, _hsl.hue, 1, _hsl.lightness).toColor(),
                  ],
                  onChanged: (v) =>
                      setState(() => _hsl = _hsl.withSaturation(v)),
                ),
                _GradientSlider(
                  label: 'Lightness',
                  value: _hsl.lightness,
                  min: 0,
                  max: 1,
                  colors: [
                    HSLColor.fromAHSL(1, _hsl.hue, _hsl.saturation, 0).toColor(),
                    HSLColor.fromAHSL(
                      1,
                      _hsl.hue,
                      _hsl.saturation,
                      0.5,
                    ).toColor(),
                    HSLColor.fromAHSL(1, _hsl.hue, _hsl.saturation, 1).toColor(),
                  ],
                  onChanged: (v) =>
                      setState(() => _hsl = _hsl.withLightness(v)),
                ),

                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => SmartDialog.dismiss(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => SmartDialog.dismiss(result: _color),
                        child: const Text('Use this colour'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the chosen colour becomes once the theme clamps it for each
/// brightness. This is the whole reason a preview is worth the space:
/// picking "hot pink" in light mode gives a *muted* primary, because
/// `withAccent` clamps lightness to a readable band — and without a
/// preview the person would find that out only after saving.
class _Preview extends StatelessWidget {
  const _Preview({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lightPrimary =
        AppColors.light.withAccent(color, Brightness.light).primary;
    final darkPrimary =
        AppColors.dark.withAccent(color, Brightness.dark).primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: c.outlineVariant, width: 1),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In the app',
                  style: AppTypography.labelSm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _DerivedSwatch(
                      color: lightPrimary,
                      background: AppColors.light.background,
                      label: 'Light',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _DerivedSwatch(
                      color: darkPrimary,
                      background: AppColors.dark.background,
                      label: 'Dark',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One derived primary colour, on its own theme's background, with a
/// check mark at the on-primary colour so the contrast is visible.
class _DerivedSwatch extends StatelessWidget {
  const _DerivedSwatch({
    required this.color,
    required this.background,
    required this.label,
  });

  final Color color;
  final Color background;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onColor =
    color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: background, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.check_rounded, color: onColor, size: 14),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A slider whose track is a gradient rather than a flat colour, so the
/// person can see what dragging left or right will do before they do it.
/// The slider's own track is transparent; the gradient Container behind
/// it is what's visible.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.pill),
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    overlayColor: c.primary.withValues(alpha: 0.12),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                      elevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

