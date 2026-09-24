import 'package:flutter/material.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A named, on-brand "coming soon" for a tab whose real screen is a later
/// issue. Deliberately simple: exists so navigation is real today rather
/// than bolted on later, without scope-creeping into #11/#12's work.
class PlaceholderTabScreen extends StatelessWidget {
  final String title;
  final String emoji;
  final String message;
  final String issueRef;

  const PlaceholderTabScreen({
    super.key,
    required this.title,
    required this.emoji,
    required this.message,
    required this.issueRef,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Coming in $issueRef',
                style: AppTypography.labelSm.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
