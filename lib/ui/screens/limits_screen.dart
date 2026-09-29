import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/limit_rule.dart';
import '../../widgets/limits/limit_card.dart';
import '../../widgets/sheets/edit_limit_sheet.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Limits & alerts (issue #15's UI half, ui-design-brief.md 7.8).
///
/// Minimum that makes the banner (#16) meaningful: one overall limit per
/// period, each with an on/off switch. Alert-level sliders, per-unit
/// limits, quiet hours and the live banner preview from 7.8 are
/// deliberately deferred — see the note at the bottom of the screen.
class LimitsScreen extends ConsumerWidget {
  const LimitsScreen({super.key});

  LimitRule? _limitFor(List<LimitRule> limits, LimitPeriod period) => limits
      .where((l) => l.scope == LimitScope.overall && l.period == period)
      .firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final limits = ref.watch(limitsProvider).value ?? const <LimitRule>[];
    final units = ref.watch(unitsProvider).value ?? const [];

    if (units.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Limits & alerts')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Add some money first — a limit needs something to '
                    'count against.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // v0.1 is effectively single-currency (ADR: overall limits cover
    // units in the limit's currency only). Take it from the first unit.
    final currencyCode = units.first.currencyCode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limits & Alerts'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            Text(
              "Set how much you'd like to keep to. The banner and Home's "
                  'status ring are built from your daily limit.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final period in LimitPeriod.values) ...[
              LimitCard(
                period: period,
                limit: _limitFor(limits, period),
                currencyCode: currencyCode,
                onTap: () => showEditLimitSheet(
                  period: period,
                  currencyCode: currencyCode,
                  existing: _limitFor(limits, period),
                ),
                onToggle: (on) async {
                  final current = _limitFor(limits, period);
                  if (current == null) {
                    // Turning on a limit that doesn't exist yet: open the
                    // sheet so an amount gets set. You can't enable a
                    // number that isn't there.
                    if (on) {
                      await showEditLimitSheet(
                        period: period,
                        currencyCode: currencyCode,
                      );
                    }
                    return;
                  }
                  await ref
                      .read(limitRepositoryProvider)
                      .setLimit(current.copyWith(enabled: on));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              "Nudges at 70% and 90% of a limit, and again when you're "
                  'over — landing with alerts in a follow-up.',
              style: AppTypography.labelSm.copyWith(color: c.onSurfaceTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
