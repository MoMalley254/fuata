// ---------------------------------------------------------------------------
// The one place a provider failure is rendered (issue #115).
//
// Before this, every `.when(error: ...)` printed the exception's own
// `toString()` straight at the person: a wall of internals they cannot act
// on, and no way forward. This card says what failed in plain words,
// offers one button that re-runs the failed provider, and keeps the
// exception's *runtime type* in small print for a bug report.
//
// The exception's own `toString()` is never shown. It can echo the
// person's data (a file path, a message body) and it never helps them.
// Only [error.runtimeType] is printed — a short tag to quote in a report.
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

class ProviderErrorCard extends StatelessWidget {
  /// What couldn't be loaded, in the person's words: "Couldn't load your
  /// money right now", not "Failed to read unitsProvider". The word
  /// "provider" never appears — it means nothing to them.
  final String headline;

  /// The `AsyncValue`'s error. Only its runtime type is ever shown.
  final Object error;

  /// Re-runs whatever failed. Usually a small closure that calls
  /// `ref.invalidate(...)` on the source providers. Null when there is
  /// nothing useful to re-run — in which case the button is not drawn at
  /// all, because a dead button is worse than none.
  final VoidCallback? onRetry;

  const ProviderErrorCard({super.key,
    required this.headline,
    required this.error,
    this.onRetry,});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.statusWarningContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: c.statusWarning,
              ),
            ),
            const SizedBox(height: AppSpacing.md,),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your data is safe — this is Fuata struggling to read its '
                  'own notes, not something you did.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Diagnostics only: a class name to quote in a bug report.
            // Not the exception's message, which can echo the person's
            // data (a path, a message body) and is never useful to them.
            Text(
              error.runtimeType.toString(),
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                color: c.onSurfaceTertiary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
