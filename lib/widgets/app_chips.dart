import 'package:flutter/material.dart';

import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

/// Selectable filter / segmented chip (pill, fully rounded).
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = selected ? c.primary.withValues(alpha: 0.15) : c.surfaceContainer;
    final fg = selected ? c.primary : c.onSurfaceVariant;
    final border = selected
        ? c.primary.withValues(alpha: 0.5)
        : c.outlineVariant.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSpacing.pill),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(label, style: AppTypography.labelMd.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Word-label chip used in the SMS rule-builder (raw text exploded into tokens).
class WordLabelChip extends StatelessWidget {
  const WordLabelChip({
    super.key,
    required this.word,
    this.assignedField,
    this.onTap,
  });

  final String word;

  /// When non-null, chip is "assigned" and takes a pastel tinted fill.
  final String? assignedField;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final assigned = assignedField != null;
    final tint = _tintFor(assignedField, c);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: assigned ? tint.withValues(alpha: 0.18) : c.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.pill),
            border: Border.all(
              color: assigned
                  ? tint.withValues(alpha: 0.5)
                  : c.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                word,
                style: AppTypography.labelMd.copyWith(
                  color: assigned ? tint : c.onSurface,
                ),
              ),
              if (assigned) ...[
                const SizedBox(width: 6),
                Text(
                  assignedField!,
                  style: AppTypography.labelSm.copyWith(
                    color: tint,
                    letterSpacing: 0.08,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _tintFor(String? field, AppColors c) {
    switch (field) {
      case 'Amount':
        return c.statusSafe;
      case 'Fee':
        return c.statusWarning;
      case 'Code':
        return c.unitBank;
      case 'Payee':
        return c.unitCard;
      default:
        return c.primary;
    }
  }
}