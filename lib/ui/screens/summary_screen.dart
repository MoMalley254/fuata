import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/summary.dart';
import '../../domain/models/unit.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/summary/more_numbers.dart';
import '../../widgets/summary/ranked_list_card.dart';
import '../../widgets/summary/spent_got_card.dart';
import '../../widgets/summary/summary_card.dart';
import '../../widgets/summary/unit_split_card.dart';
import '../providers/app_providers.dart';
import '../providers/summary_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Issue #23 / US-12, ui-design-brief.md 7.11: Day / Week / Month as
/// story-style cards. Simple by default; the numbers sit behind
/// "Show me more".
class SummaryScreen extends ConsumerStatefulWidget {
  final SummaryPeriod initialPeriod;
  const SummaryScreen({super.key, this.initialPeriod = SummaryPeriod.day});

  @override
  ConsumerState<SummaryScreen> createState () => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late SummaryPeriod _period = widget.initialPeriod;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(summaryProvider(_period));
    final units = ref.watch(unitsProvider).value ?? const <MoneyUnit>[];
    final unitById = {for (final u in units) u.id: u};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
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
            Row(
              children: [
                for (final p in SummaryPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: AppChoiceChip(
                      label: p.label,
                      selected: p == _period,
                      onTap: () => setState(() => _period = p),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...summaryAsync.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ],
              error: (e, st) => [Text('Something went wrong: $e')],
              data: (data) => _cards(context, data, unitById),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cards(BuildContext context, SummaryData data, Map<String, MoneyUnit> unitById) {
    final c = context.colors;
    final s = data.summary;
    final cc = data.currencyCode;
    const gap = SizedBox(height: AppSpacing.md);

    return [
      SummaryCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.hasActivity ? '🧾' : '🌤️',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                s.story(cc),
                style: AppTypography.bodyLg.copyWith(color: c.onSurface),
              ),
            ),
          ],
        ),
      ),
      if (s.hasActivity) ...[
        gap,
        SpentGotCard(
          spentMinor: s.spentMinor,
          gotMinor: s.gotMinor,
          currencyCode: cc,
        ),
        gap,
        RankedListCard(
          title: 'Where it went',
          items: s.spentTo,
          currencyCode: cc,
          emptyText: 'Nothing you spent has a name on it yet.',
        ),
        gap,
        RankedListCard(
          title: 'Where it came from',
          items: s.gotFrom,
          currencyCode: cc,
          emptyText: 'Nothing came in ${s.period.thisWord} with a name on it.',
        ),
        if (s.spentByUnit.length > 1) ...[
          gap,
          UnitSplitCard(
            shares: s.spentByUnit,
            unitById: unitById,
            totalMinor: s.spentMinor,
            currencyCode: cc,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        MoreNumbers(summary: s, currencyCode: cc),
      ],
    ];
  }
}