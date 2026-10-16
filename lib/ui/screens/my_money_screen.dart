import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/widgets/personalization/amount_visibility_toggle.dart';
import 'package:fuata/widgets/provider_error_card.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/money.dart';
import '../../domain/models/unit.dart';
import '../../routing/routes.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/sheets/edit_unit_sheet.dart';
import '../../widgets/unit_list_tile.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// My money (ui-design-brief.md section 7.5): a total with a privacy eye,
/// then every unit as a full-width row. Tapping a unit opens its detail
/// page; "+ Add something" opens the same sheet used to edit a unit.
/// Long-press a row and drag to reorder (#117); the order is shared with
/// Home's My money row.
class MyMoneyScreen extends ConsumerStatefulWidget {
  const MyMoneyScreen({super.key});

  @override
  ConsumerState<MyMoneyScreen> createState() => _MyMoneyScreenState();
}

class _MyMoneyScreenState extends ConsumerState<MyMoneyScreen> {
  // The order on screen, so a dropped row stays put while the saved order
  // makes its way back through the database stream (same reason as Home's
  // UnitRow). Reset only when a genuinely new list arrives.
  List<MoneyUnit>? _source;
  List<MoneyUnit> _units = const [];

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;
    setState(() {
      _units = List.of(_units);
      _units.insert(newIndex, _units.removeAt(oldIndex));
    });
    ref.read(unitRepositoryProvider).reorderUnits([
      for (final u in _units) u.id,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeStateProvider);
    final archivedCount = ref.watch(archivedUnitsProvider).length;
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Money'),
        actions: [
          IconButton(
            onPressed: () => showEditUnitSheet(context),
            icon: Icon(Icons.add),
          ),
          const AmountVisibilityToggle(),
          // Only shown when there is something to show. The count lives in the
          // menu item rather than on the app bar itself, so a person isn't
          // nagged by a badge for units they deliberately put away.
          if (archivedCount > 0)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'archived') context.push(Routes.archivedUnitsPath);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archived',
                  child: Row(
                    children: [
                      const Icon(Icons.archive_outlined, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Archived ($archivedCount)'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: homeAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load your money right now",
            error: e,
            onRetry: () => ref.invalidate(homeStateProvider),
          ),
          data: (state) {
            final currency = state.units.isNotEmpty
                ? state.units.first.currencyCode
                : 'KES';
            final total = state.balanceByUnit.values.fold(0, (a, b) => a + b);

            if (!identical(_source, state.units)) {
              _source = state.units;
              _units = List.of(state.units);
            }

            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                100,
              ),
              // Long-press on every platform, so the chevron isn't fighting
              // a desktop drag handle for the same corner of the row.
              buildDefaultDragHandles: false,
              onReorderStart: (_) => HapticFeedback.mediumImpact(),
              onReorder: _onReorder,
              proxyDecorator: (child, _, _) => Transform.scale(
                scale: 1.02,
                child: Material(color: Colors.transparent, child: child),
              ),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Altogether you have',
                            style: AppTypography.bodyMd.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                          AmountText(
                            minor: total,
                            currencyCode: currency,
                            style: AppTypography.displayHeroMobile.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                        ],
                      ),
                      AmountVisibilityToggle(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Reordering is invisible until someone tries it, so say
                  // so once there is something to reorder.
                  if (_units.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'Press and hold to reorder',
                        style: AppTypography.bodySm.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              itemCount: _units.length,
              itemBuilder: (context, i) {
                final unit = _units[i];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(unit.id),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: UnitListTile(
                      emoji: unit.iconEmoji,
                      color: unit.color,
                      name: unit.name,
                      balanceText: Money(
                        state.balanceByUnit[unit.id] ?? 0,
                        unit.currencyCode,
                      ).format(),
                      lastVerifiedAt: unit.lastVerifiedAt,
                      hideAmount: hidden,
                      onTap: () => context.push(Routes.unitFor(unit.id)),
                    ),
                  ),
                );
              },
              footer: InkWell(
                onTap: () => showEditUnitSheet(context),
                borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.outlineVariant),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.unitTileRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: c.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Add something',
                        style: AppTypography.bodyLg.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
