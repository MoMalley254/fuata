import 'package:flutter/material.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:fuata/ui/theme/app_typography.dart';

import '../ui/theme/app_status.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.labelOverride});
  final BudgetStatus status;
  final String? labelOverride;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = status.fg(c);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: status.bg(c),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: status.border(c)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6,),
          Text(
            labelOverride ?? status.label,
            style: AppTypography.labelSm.copyWith(color: fg),
          )
        ],
      ),
    );
  }
}
