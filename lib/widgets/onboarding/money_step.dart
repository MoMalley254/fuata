import 'package:flutter/material.dart';

import '../../domain/models/money.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/label.dart';
import 'step_frame.dart';
import 'unit_draft_sheet.dart';

/// Step 2 — add your money (ui-design-brief.md 7.1): quick-pick tiles, each
/// opening a tiny sheet. Units added here live in the onboarding draft until
/// the flow is finished.
class MoneyStep extends StatelessWidget {
  const MoneyStep({
    super.key,
    required this.units,
    required this.onSaveUnit,
    required this.onRemoveUnit,
    required this.onContinue,
    required this.onSkip,
    required this.currencyCode,
  });

  final List<MoneyUnit> units;
  final ValueChanged<MoneyUnit> onSaveUnit;
  final ValueChanged<String> onRemoveUnit;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final String currencyCode;

  KindDefaults _defaultsFor(UnitKind kind) =>
      kindQuickPicks.firstWhere((k) => k.kind == kind);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StepFrame(
      title: 'Add your money',
      subtitle: 'Pick the places you keep it. You can add more any time.',
      primaryLabel: 'Continue',
      // Nothing added yet: the skip link is the way forward.
      onPrimary: units.isEmpty ? null : onContinue,
      skipLabel: "Skip, I'll add it later",
      onSkip: onSkip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WhatIsAUnitCard(),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final k in kindQuickPicks)
                _KindTile(
                  defaults: k,
                  onTap: () => showUnitDraftSheet(
                    context,
                    defaults: k,
                    onSave: onSaveUnit,
                    currencyCode: currencyCode,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ReassuranceNote(
            icon: Icons.lock_outline_rounded,
            text: 'We never ask for account or card numbers.',
          ),
          if (units.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Label('Added so far'),
            const SizedBox(height: AppSpacing.sm),
            for (final u in units) ...[
              _AddedRow(
                unit: u,
                onTap: () => showUnitDraftSheet(
                  context,
                  defaults: _defaultsFor(u.kind),
                  existing: u,
                  onSave: onSaveUnit,
                  onRemove: () => onRemoveUnit(u.id),
                  currencyCode: currencyCode
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              'Tap one to change it.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _WhatIsAUnitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s a "unit"?',
            style: AppTypography.labelLg.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A unit is just a place your money lives: your cash, your '
            'M-PESA, a bank account.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Why add them?',
            style: AppTypography.labelMd.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            "You can see what's in each one, moving money between them "
            "doesn't count as spending, and Fuata can read messages for "
            'each one.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          // A tiny illustration of three tiles — same shape and colour as
          // the picker below, so the connection is obvious.
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                _MiniTile(defaults: kindQuickPicks[i]),
                if (i < 2) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.defaults});
  final KindDefaults defaults;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(defaults.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            defaults.label,
            style: AppTypography.labelSm.copyWith(color: c.onSurface),
          ),
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({required this.defaults, required this.onTap});

  final KindDefaults defaults;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          width: 104,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(defaults.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                defaults.label,
                textAlign: TextAlign.center,
                style: AppTypography.labelMd.copyWith(color: c.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddedRow extends StatelessWidget {
  const _AddedRow({required this.unit, required this.onTap});

  final MoneyUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount =
        '${currencySymbol(unit.currencyCode)}${Money(unit.openingBalanceMinor, unit.currencyCode).format()}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: unit.color.withValues(alpha: 0.18),
                child: Text(unit.iconEmoji),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  unit.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(color: c.onSurface),
                ),
              ),
              Text(
                amount,
                style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
