import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/outings.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/outing.dart';
import '../../widgets/personalization/label.dart';
import '../../widgets/provider_error_card.dart';
import '../../widgets/sheets/edit_outing_sheet.dart';
import '../../widgets/status_pill.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_status.dart';
import '../theme/app_typography.dart';

/// Outings (issue #30): named temporary budgets with their own window.
/// The person's trip list — active at top, then upcoming, then past.
class OutingsScreen extends ConsumerWidget {
  const OutingsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditOutingSheet(),
    );
  }

  Future<void> _edit(BuildContext context, Outing outing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditOutingSheet(existing: outing),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outingsAsync = ref.watch(outingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Outings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: outingsAsync.when(
          loading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load your outings",
            error: e,
            onRetry: () => ref.invalidate(outingsProvider),
          ),
          data: (outings) {
            final now = DateTime.now();
            final active = outings.where((o) => o.isActive(now)).toList();
            final upcoming = outings.where((o) => o.isUpcoming).toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
            final past = outings.where((o) => o.isPast).toList()
              ..sort((a, b) => b.endAt.compareTo(a.endAt));

            if (outings.isEmpty) {
              return _EmptyOutings(onCreate: () => _create(context));
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'A temporary budget for a trip, a weekend, a night out. '
                      'Fuata shows it on the banner and Home while it runs, '
                      'then goes back to your everyday budget.',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                if (active.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Label('Active'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final o in active) ...[
                    _OutingTile(
                      outing: o,
                      highlight: true,
                      onTap: () => _edit(context, o),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Label('Coming up'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final o in upcoming) ...[
                    _OutingTile(
                      outing: o,
                      onTap: () => _edit(context, o),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Label('Past'),
                  const SizedBox(height: AppSpacing.sm),
                  for (final o in past) ...[
                    _OutingTile(
                      outing: o,
                      dim: true,
                      onTap: () => _edit(context, o),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyOutings extends StatelessWidget {
  const _EmptyOutings({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏝️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No outings yet',
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Going somewhere? Set a budget for the trip and Fuata '
                  'shows how it\'s going on the banner, then back to your '
                  'everyday budget when you\'re home.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCreate,
                child: const Text('Plan an outing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutingTile extends ConsumerWidget {
  const _OutingTile({
    required this.outing,
    required this.onTap,
    this.highlight = false,
    this.dim = false,
  });

  final Outing outing;
  final VoidCallback onTap;
  final bool highlight;
  final bool dim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final txs = ref.watch(transactionsProvider).value ?? const [];
    final units = ref.watch(allUnitsProvider).value ?? const [];
    final currencyByUnit = {for (final u in units) u.id: u.currencyCode};
    final spent = Outings.spentIn(
      outing,
      txs,
      currencyByUnit: currencyByUnit,
    );
    final status = Outings.statusFor(outing, spent);
    final remaining = outing.amountMinor - spent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(
              color: highlight
                  ? c.primary.withValues(alpha: 0.55)
                  : c.outlineVariant.withValues(alpha: 0.35),
              width: highlight ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      outing.name,
                      style: AppTypography.labelLg.copyWith(
                        color: dim ? c.onSurfaceVariant : c.onSurface,
                      ),
                    ),
                  ),
                  StatusPill(status: status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _subtitle(spent),
                style: AppTypography.bodySm.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              if (highlight && status != SpendStatus.safe) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  remaining >= 0
                      ? '${friendlyOutingMoney(remaining, outing.currencyCode)} left'
                      : 'Over by ${friendlyOutingMoney(-remaining, outing.currencyCode)}',
                  style: AppTypography.bodySm.copyWith(
                    color: status.fg(c),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(int spent) {
    final now = DateTime.now();
    final when = outing.isActive(now)
        ? 'ends ${_short(outing.endAt)}'
        : outing.isUpcoming
        ? 'starts ${_short(outing.startAt)}'
        : 'ended ${_short(outing.endAt)}';
    return '${friendlyOutingMoney(outing.amountMinor, outing.currencyCode)} '
        '· ${outing.dayCount} day${outing.dayCount == 1 ? '' : 's'} · $when';
  }

  static String _short(DateTime at) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[at.weekday - 1]} ${at.day} ${months[at.month - 1]}';
  }
}