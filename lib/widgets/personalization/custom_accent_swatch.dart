import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';

/// The "pick anything" swatch. Sits after the presets in both the
/// welcome step and the profile block, and shows itself as selected
/// when the current accent isn't one of them.
///
/// Lives here rather than in either caller so the two screens can't
/// drift apart — a custom colour is selected in *both* or in neither.
class CustomAccentSwatch extends StatelessWidget {
  const CustomAccentSwatch({
    super.key,
    required this.selected,
    required this.size,
    this.onTap,
  });

  /// True when the current accent is not one of [AppAccents.swatches].
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pill),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // A rainbow ring, because "any colour" is the whole point of
          // this swatch and a single flat colour would look like a ninth
          // preset. First and last colours match so the sweep is seamless.
          gradient: const SweepGradient(
            colors: [
              Color(0xFFE53935), // red
              Color(0xFFFB8C00), // orange
              Color(0xFFFDD835), // yellow
              Color(0xFF43A047), // green
              Color(0xFF00ACC1), // cyan
              Color(0xFF3949AB), // indigo
              Color(0xFF8E24AA), // violet
              Color(0xFFE53935), // back to red
            ],
          ),
          border: Border.all(
            color: selected ? c.onSurface : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          selected ? Icons.check_rounded : Icons.colorize_rounded,
          color: Colors.white,
          size: size * 0.5,
          shadows: const [Shadow(blurRadius: 2, color: Colors.black45)],
        ),
      ),
    );
  }
}