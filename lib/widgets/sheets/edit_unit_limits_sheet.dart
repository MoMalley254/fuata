import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../limits/unit_limit_summary.dart';

/// Per-unit limits (ui-design-brief.md 7.8 "under More", issue #63): a
/// daily, weekly and monthly limit for one money unit. A blank field means
/// "no limit for that period" — so the same sheet adds, edits and removes.
Future<void> showEditUnitLimitsSheet({required MoneyUnit unit}) async {
  return await SmartDialog.show(
    alignment: Alignment.bottomCenter,
    clickMaskDismiss: true,
    animationType: SmartAnimationType.scale,
    builder: (_) => EditUnitLimitsSheet(unit: unit),
  );
}

class EditUnitLimitsSheet extends ConsumerStatefulWidget {
  final MoneyUnit unit;
  const EditUnitLimitsSheet({super.key, required this.unit});

  @override
  ConsumerState<EditUnitLimitsSheet> createState() =>
      _EditUnitLimitsSheetState();
}

class _EditUnitLimitsSheetState extends ConsumerState<EditUnitLimitsSheet> {
  late final Map<LimitPeriod, LimitRule> _existing;
  late final Map<LimitPeriod, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _existing = unitLimitsFor(
      ref.read(limitsProvider).value ?? const <LimitRule>[],
      widget.unit.id,
    );
    _controllers = {
      for (final p in LimitPeriod.values)
        p: TextEditingController(
          text: _existing[p] == null
              ? ''
              : Money(_existing[p]!.amountMinor, widget.unit.currencyCode)
              .format()
              .replaceAll(',', ''),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(LimitPeriod p) => switch (p) {
    LimitPeriod.day => 'Daily',
    LimitPeriod.week => 'Weekly',
    LimitPeriod.month => 'Monthly',
  };

  Future<void> _save() async {
    // Validate everything first so a typo in one field doesn't leave the
    // other two half-saved.
    final amounts = <LimitPeriod, int?>{};
    for (final p in LimitPeriod.values) {
      final text = _controllers[p]!.text.trim();
      if (text.isEmpty) {
        amounts[p] = null;
        continue;
      }
      try {
        final money = Money.parseMajor(text, widget.unit.currencyCode);
        if (money.minor <= 0) {
          setState(() => _error = '${_label(p)}: amount must be more than zero');
          return;
        }
        amounts[p] = money.minor;
      } on FormatException {
        setState(() => _error = "${_label(p)}: that doesn't look like an amount");
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(limitRepositoryProvider);
    // New limits start with the levels the person already chose.
    final (warn, danger) = LimitRule.levelsFrom(
      ref.read(limitsProvider).value ?? const <LimitRule>[],
    );

    try {
      for (final p in LimitPeriod.values) {
        final existing = _existing[p];
        final amount = amounts[p];
        if (amount == null) {
          if (existing != null) await repo.deleteLimit(existing.id);
          continue;
        }
        await repo.setLimit(
          LimitRule(
            id: existing?.id ??
                LimitRule.idFor(LimitScope.unit, p, widget.unit.id),
            scope: LimitScope.unit,
            unitId: widget.unit.id,
            period: p,
            amountMinor: amount,
            currencyCode: widget.unit.currencyCode,
            warnAt: existing?.warnAt ?? warn,
            dangerAt: existing?.dangerAt ?? danger,
            enabled: existing?.enabled ?? true,
          ),
        );
      }
      if (mounted) SmartDialog.dismiss();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save, please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final symbol = currencySymbol(widget.unit.currencyCode);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
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
                    'Limits for ${widget.unit.name}',
                    style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Only counts spending from this unit. Leave a box empty '
                        'for no limit.',
                    style: AppTypography.bodySm.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final p in LimitPeriod.values) ...[
                    TextField(
                      controller: _controllers[p],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _label(p),
                        prefixText: symbol,
                      ),
                      style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: AppTypography.bodySm.copyWith(color: c.statusDanger),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
