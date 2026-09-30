import 'package:flutter/material.dart';

import '../../domain/logic/summary.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'summary_card.dart';

/// The "Show me more" expander: the plain numbers behind the story, for
/// people who want them. Collapsed by default (US-12: simple by default).
class MoreNumbers extends StatefulWidget {
  const MoreNumbers({
    super.key,
    required this.summary,
    required this.currencyCode,
  });

  final PeriodSummary summary;
  final String currencyCode;

  @override
  State<MoreNumbers> createState() => _MoreNumbersState();
}

class _MoreNumbersState extends State<MoreNumbers> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final cc = widget.currencyCode;
    final before = s.period.previousWord;

    final rows = <(String, String)>[
      ('Spent', friendlyMoney(s.spentMinor, cc)),
      ('Got', friendlyMoney(s.gotMinor, cc)),
      (
        'Got minus spent',
        '${s.netMinor < 0 ? '-' : ''}${friendlyMoney(s.netMinor.abs(), cc)}',
      ),
      ('Payments and receipts', '${s.transactionCount}'),
      if (s.period != SummaryPeriod.day && s.daysSoFar > 0)
        ('Spent per day, on average', friendlyMoney(s.averageSpentPerDayMinor, cc)),
      if (s.unnamedSpentMinor > 0)
        ('Spent with no name on it', friendlyMoney(s.unnamedSpentMinor, cc)),
      ('Spent by this time $before', friendlyMoney(s.previousSpentMinor, cc)),
      ('Got by this time $before', friendlyMoney(s.previousGotMinor, cc)),
    ];

    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(
            _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          ),
          label: Text(_open ? 'Show less' : 'Show me more'),
        ),
        if (_open)
          SummaryCard(
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: AppTypography.bodyMd.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          value,
                          style: AppTypography.labelLg.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
