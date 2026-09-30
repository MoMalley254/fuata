import 'package:flutter/material.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/action_row.dart';
import '../sheets/edit_unit_limits_sheet.dart';
import 'unit_limit_summary.dart';

/// "More": limits for one money unit at a time (ui-design-brief.md 7.8,
/// issue #63). Collapsed unless some unit already has a limit, so the
/// simple Daily / Weekly / Monthly cards stay the whole story by default.
class UnitLimitsSection extends StatelessWidget {
  final List<MoneyUnit> units;
  final List<LimitRule> limits;
  const UnitLimitsSection({super.key, required this.units, required this.limits});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = units.where((u) => !u.archived).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final anySet = limits.any((l) => l.scope == LimitScope.unit);
    return Theme(
      // ExpansionTile draws divider lines by default; the rest of this
      // screen is bordered cards, so drop them.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: anySet,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'More: limits for one unit',
          style: AppTypography.bodyLg.copyWith(color: c.onSurface),
        ),
        subtitle: Text(
          'E.g. keep mobile money under a number of its own.',
          style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
        ),
        children: [
          for (final u in active) ...[
            ActionRow(
              icon: Icons.tune_rounded,
              title: u.name,
              subtitle: unitLimitSummary(limits, u),
              onTap: () => showEditUnitLimitsSheet(unit: u),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
