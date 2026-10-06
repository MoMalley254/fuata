import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// The shared "nothing here yet, but here's what this screen is for" state
/// (issue #87, finding F10).
///
/// Built for the rule builder's empty screen, and shaped so it can be
/// reused where a screen has nothing to show but the person could still
/// learn something: the empty Archived screen (#80, F9) and the empty
/// Week Peek (#82, F6).
///
/// Every piece of content is a slot — each caller says what its own thing
/// is; this widget only owns the layout. The `example` slot in particular
/// is a `Widget?` rather than a fixed shape, because "what the thing looks
/// like" differs per screen: word chips here, a unit row for Archived, a
/// bar strip for Week Peek.
class EducationalEmptyState extends StatelessWidget {
  const EducationalEmptyState({
    super.key,
    required this.emoji,
    required this.headline,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
    this.steps = const [],
    this.example,
    this.footer,
  });

  /// Shown large, in a tinted circle — the same treatment as the
  /// onboarding welcome (#77), so an empty screen reads as inviting
  /// rather than blank.
  final String emoji;

  final String headline;

  /// One sentence, plain language. What the thing is, or what it does.
  final String description;

  /// Numbered 1, 2, 3… in the order given. One short line each. Empty to
  /// skip the numbered block entirely.
  final List<String> steps;

  /// A small mock of what the thing looks like. A slot, not a fixed
  /// shape — see the class doc.
  final Widget? example;

  final String primaryLabel;
  final VoidCallback onPrimary;

  /// One quiet line under the button, e.g. a privacy note. Optional.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Center > SingleChildScrollView > SizedBox(width: infinity) is the
    // fix for the off-centre the finding described. A bare
    // Column(mainAxisAlignment: center) centres vertically but leaves
    // the button hugging its own width at the start of the cross axis;
    // stretching the SizedBox and centring the column's children is what
    // makes the whole stack sit centred on a tall, otherwise-empty screen.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              if (steps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                for (final (i, step) in steps.indexed) ...[
                  _Step(number: i + 1, text: step),
                  if (i < steps.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
              if (example != null) ...[
                const SizedBox(height: AppSpacing.md),
                example!,
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  footer!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMd.copyWith(color: c.onSurface),
          ),
        ),
      ],
    );
  }
}