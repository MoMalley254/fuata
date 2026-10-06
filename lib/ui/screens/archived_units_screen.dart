import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/logic/ledger.dart';
import '../../domain/models/money.dart';
import '../../domain/models/unit.dart';
import '../../routing/routes.dart';
import '../../widgets/personalization/educational_empty_state.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Units the person has put away (finding F9, issue #80).
///
/// Reached from the My money app bar's overflow menu, which only appears
/// when there is at least one archived unit — so the "nothing here" state
/// below is defensive rather than something a person navigates to. It can
/// still show if the last archived unit is restored while this screen is
/// open, which is a real race.
class ArchivedUnitsScreen extends ConsumerWidget {
  const ArchivedUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(allUnitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived')),
      body: SafeArea(
        child: archivedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => Center(child: Text('Something went wrong: $e')),
          data: (_) {
            final archived = ref.watch(archivedUnitsProvider);
            if (archived.isEmpty) {
              return EducationalEmptyState(
                emoji: '📦',
                headline: 'Nothing archived',
                description:
                "Units you put away wait here, with their history and "
                    'rules kept.',
                primaryLabel: 'Back to My money',
                onPrimary: () => context.pop(),
              );
            }

            final txAsync = ref.watch(transactionsProvider);
            return txAsync.when(
              loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, st) => Center(child: Text('Something went wrong: $e')),
              data: (transactions) {
                final balances = {
                  for (final u in archived)
                    u.id: Ledger.balanceOf(u, transactions),
                };
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.margin,
                    AppSpacing.sm,
                    AppSpacing.margin,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      'Put away, not gone. Their history still counts toward '
                          'totals, and restoring one brings it back exactly as it '
                          'was.',
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final u in archived) ...[
                      _ArchivedUnitTile(
                        unit: u,
                        balanceMinor: balances[u.id] ?? 0,
                        onTap: () => context.push(Routes.unitFor(u.id)),
                        onRestore: () => _restore(context, ref, u),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _restore(
      BuildContext context,
      WidgetRef ref,
      MoneyUnit unit,
      ) async {
    await ref.read(unitRepositoryProvider).unarchiveUnit(unit.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${unit.name} is back.')),
    );
  }
}

class _ArchivedUnitTile extends StatelessWidget {
  const _ArchivedUnitTile({
    required this.unit,
    required this.balanceMinor,
    required this.onTap,
    required this.onRestore,
  });

  final MoneyUnit unit;
  final int balanceMinor;
  final VoidCallback onTap;
  final VoidCallback onRestore;

  /// "Archived on 15 Oct", or just "Archived" for a unit that predates the
  /// column (or came out of an older backup). Local time: the stored value
  /// is UTC.
  String get _archivedLine {
    final at = unit.archivedAt?.toLocal();
    if (at == null) return 'Archived';
    return 'Archived on ${DateFormat('d MMM').format(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(
              color: c.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unit.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unit.iconEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.name,
                      style: AppTypography.bodyLg.copyWith(
                        color: c.onSurface,
                      ),
                    ),
                    Text(
                      '$_archivedLine · ${Money(balanceMinor, unit.currencyCode).format()}',
                      style: AppTypography.bodySm.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: onRestore,
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}