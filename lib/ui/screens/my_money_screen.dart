import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/money.dart';
import '../../routing/routes.dart';
import '../../widgets/sheets/edit_unit_sheet.dart';
import '../../widgets/unit_list_tile.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// My money (ui-design-brief.md section 7.5): a total with a privacy eye,
/// then every unit as a full-width row. Tapping a unit opens its detail
/// page; "+ Add something" opens the same sheet used to edit a unit.
class MyMoneyScreen extends ConsumerStatefulWidget {
  const MyMoneyScreen({super.key});

  @override
  ConsumerState<MyMoneyScreen> createState() => _MyMoneyScreenState();
}

class _MyMoneyScreenState extends ConsumerState<MyMoneyScreen> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeStateProvider);
    final archivedCount = ref.watch(archivedUnitsProvider).length;
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
          title: const Text('My Money'),
        actions: [
          IconButton(
              onPressed: () => showEditUnitSheet(context),
              icon: Icon(Icons.add)
          ),
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
          error: (e, st) => Center(child: Text('Something went wrong: $e')),
          data: (state) {
            final currency = state.units.isNotEmpty
                ? state.units.first.currencyCode
                : 'KES';
            final total = state.balanceByUnit.values.fold(0, (a, b) => a + b);

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                100,
              ),
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
                        Text(
                          _hidden ? '•••••' : Money(total, currency).format(),
                          style: AppTypography.displayHeroMobile.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final unit in state.units) ...[
                  UnitListTile(
                    emoji: unit.iconEmoji,
                    color: unit.color,
                    name: unit.name,
                    balanceText: Money(
                      state.balanceByUnit[unit.id] ?? 0,
                      unit.currencyCode,
                    ).format(),
                    lastVerifiedAt: unit.lastVerifiedAt,
                    hideAmount: _hidden,
                    onTap: () => context.push(Routes.unitFor(unit.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                InkWell(
                  onTap: () => showEditUnitSheet(context),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.unitTileRadius,
                  ),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
