import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';
import 'package:fuata/ui/providers/capture_providers.dart';
import 'package:fuata/widgets/provider_error_card.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../widgets/activity/empty_activity.dart';
import '../../widgets/activity/grouped_list.dart';
import '../../widgets/app_chips.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// One filter at a time: everything, a transaction type, or a single unit.
/// (ui-design-brief.md section 7.4: "Filter chips on top: All / Spent /
/// Got / by unit.")
sealed class Filter {
  const Filter();
  bool matches(MoneyTransaction t);
}

class _AllFilter extends Filter {
  const _AllFilter();
  @override
  bool matches(MoneyTransaction t) => true;
}

class _TypeFilter extends Filter {
  const _TypeFilter(this.type);
  final TxType type;
  @override
  bool matches(MoneyTransaction t) => t.type == type;
}

class _UnitFilter extends Filter {
  const _UnitFilter(this.unitId);
  final String unitId;
  @override
  bool matches(MoneyTransaction t) => t.unitId == unitId;
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  Filter _filter = const _AllFilter();

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);
    final unitsAsync = ref.watch(allUnitsProvider);
    final inboxCount = ref.watch(reviewInboxCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Summaries',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push(Routes.summaryPath),
          ),
          IconButton(
            tooltip: 'Caught from my messages',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.inbox_rounded),
                if (inboxCount > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      alignment: Alignment.center,
                      child: Text(
                        inboxCount > 99 ? '99+' : '$inboxCount',
                        style: AppTypography.labelSm.copyWith(
                          color: context.colors.onPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push(Routes.inboxPath),
          ),
        ],
      ),
      body: SafeArea(
        child: unitsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load your activity right now",
            error: e,
            onRetry: () => ref.invalidate(allUnitsProvider),
          ),
          data: (units) {
            final unitById = {for (final u in units) u.id: u};
            return txAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, st) => ProviderErrorCard(
                headline: "Could not load your activity right now",
                error: e,
                onRetry: () => ref.invalidate(transactionsProvider),
              ),
              data: (transactions) {
                // Pending (unconfirmed) captures live in the review inbox
                // (#21/#22), not built yet, so Activity only shows
                // confirmed transactions for now.
                final confirmed = transactions
                    .where((t) => t.isConfirmed)
                    .toList();
                final filtered = confirmed.where(_filter.matches).toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                return Column(
                  children: [
                    FilterBar(
                      units: units,
                      selected: _filter,
                      onSelected: (f) => setState(() {
                        _filter = f;
                      }),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const EmptyActivity()
                          : GroupedList(
                              transactions: filtered,
                              unitById: unitById,
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  final List<MoneyUnit> units;
  final Filter selected;
  final ValueChanged<Filter> onSelected;
  const FilterBar({
    super.key,
    required this.units,
    required this.selected,
    required this.onSelected,
  });

  bool _isSelected(Filter f) {
    if (f is _AllFilter) return selected is _AllFilter;
    if (f is _TypeFilter && selected is _TypeFilter) {
      return (selected as _TypeFilter).type == f.type;
    }
    if (f is _UnitFilter && selected is _UnitFilter) {
      return (selected as _UnitFilter).unitId == f.unitId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final chips = <MapEntry<String, Filter>>[
      const MapEntry('All', _AllFilter()),
      const MapEntry('Spent', _TypeFilter(TxType.spent)),
      const MapEntry('Got', _TypeFilter(TxType.got)),
      const MapEntry('Moved', _TypeFilter(TxType.moved)),
      for (final u in units)
        MapEntry('${u.iconEmoji} ${u.name}', _UnitFilter(u.id)),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.margin,
          vertical: AppSpacing.sm,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final entry = chips[i];
          return AppChoiceChip(
            label: entry.key,
            selected: _isSelected(entry.value),
            onTap: () => onSelected(entry.value),
          );
        },
      ),
    );
  }
}
