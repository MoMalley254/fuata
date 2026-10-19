import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/logic/ledger.dart';
import 'package:fuata/widgets/personalization/amount_visibility_toggle.dart';
import 'package:fuata/widgets/provider_error_card.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/unit.dart';
import '../../routing/routes.dart';
import '../../widgets/activity/empty_activity.dart';
import '../../widgets/activity/grouped_list.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/limits/unit_limit_summary.dart';
import '../../widgets/personalization/action_row.dart';
import '../../widgets/sheets/edit_unit_limits_sheet.dart';
import '../../widgets/sheets/edit_unit_sheet.dart';
import '../../widgets/sheets/update_balance_sheet.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Unit page (ui-design-brief.md section 7.5): balance, "Update balance",
/// edit name/icon/colour, archive, and that unit's recent activity —
/// reusing GroupedList/showTransactionDetail from the Activity screen
/// rather than a second implementation.
///
/// The per-unit limit row is live as of #63 (it opens the same sheet as
/// Limits & alerts > More); the message-reading row is live as of #20 — it opens the rule builder
/// pre-set to this unit and shows how many rules the unit already has.

class UnitDetailScreen extends ConsumerWidget {
  final String unitId;
  const UnitDetailScreen({super.key, required this.unitId});

  void _confirmArchive(BuildContext context, WidgetRef ref, MoneyUnit unit) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${unit.name}?'),
        content: const Text(
          "It'll disappear from Home, My money and the banner. Its history "
          'stays safe, and its reading rules pause.\n\n'
          "You can restore it any time from My money → Archived.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(unitRepositoryProvider).archiveUnit(unit.id);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              // Stay on the page: an archived unit now has a page worth
              // looking at (the notice, the Restore button) rather than
              // being a dead end, so there's no reason to bounce the
              // person back.
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _confirmUnarchive(BuildContext context, WidgetRef ref, MoneyUnit unit) {
    // No dialog here: restoring is not destructive, and the notice on the
    // page already says what the button does. A confirm step would just be
    // an extra tap on the only action a person came here to take.
    ref.read(unitRepositoryProvider).unarchiveUnit(unit.id).then((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${unit.name} is back.')));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;
    final unitsAsync = ref.watch(allUnitsProvider);
    final txAsync = ref.watch(transactionsProvider);

    return unitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, st) => ProviderErrorCard(
        headline: "Couldn't load this unit right now",
        error: e,
        onRetry: () => ref.invalidate(allUnitsProvider),
      ),
      data: (units) {
        final unit = units.where((u) => u.id == unitId).firstOrNull;
        if (unit == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                "This one's gone.",
                style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          );
        }

        return txAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load its's activity right now",
            error: e,
            onRetry: () => ref.invalidate(transactionsProvider),
          ),
          data: (allTransactions) {
            final balance = Ledger.balanceOf(unit, allTransactions);
            final unitTransactions =
                allTransactions
                    .where((t) => t.unitId == unit.id && t.isConfirmed)
                    .toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

            return Scaffold(
              appBar: AppBar(
                title: Text(unit.name),
                actions: [
                  const AmountVisibilityToggle(),
                  if (!unit.archived)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () =>
                          showEditUnitSheet(context, existing: unit),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'archive':
                          _confirmArchive(context, ref, unit);
                        case 'restore':
                          _confirmUnarchive(context, ref, unit);
                      }
                    },
                    itemBuilder: (_) => [
                      if (unit.archived)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive_outlined, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text('Restore'),
                            ],
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text('Archive'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: unit.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadiusHero,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unit.archived) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: c.statusWarningContainer,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.unitTileRadius,
                                ),
                                border: Border.all(
                                  color: c.statusWarningBorder,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.archive_outlined,
                                    size: 20,
                                    color: c.statusWarning,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      "This one's archived. Its history still counts, and its "
                                      'reading rules are paused. Use Restore above to bring it back.',
                                      style: AppTypography.bodySm.copyWith(
                                        color: c.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Row(
                            children: [
                              Text(
                                unit.iconEmoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                unit.name,
                                style: AppTypography.headlineSm.copyWith(
                                  color: c.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AmountText(
                            minor: balance,
                            currencyCode: unit.currencyCode,
                            style: AppTypography.displayHeroMobile.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            unit.lastVerifiedAt == null
                                ? 'Not checked yet'
                                : 'Last checked ${DateFormat('d MMM, h:mm a').format(unit.lastVerifiedAt!)}',
                            style: AppTypography.bodySm.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.tonal(
                            // Disabled when archived: a balance you can't spend isn't a balance
                            // you update. The button stays visible (rather than disappearing) so
                            // the layout doesn't jump and the tooltip can say why.
                            onPressed: unit.archived
                                ? null
                                : () => showUpdateBalanceSheet(
                                    unit: unit,
                                    currentBalanceMinor: balance,
                                  ),
                            child: const Text('Update balance'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ActionRow(
                      icon: Icons.speed_rounded,
                      title: 'Limit for this unit',
                      subtitle: unitLimitSummary(
                        ref.watch(limitsProvider).value ?? const <LimitRule>[],
                        unit,
                        masked: hidden,
                      ),
                      onTap: () => showEditUnitLimitsSheet(unit: unit),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Builder(
                      builder: (context) {
                        final templates =
                            ref.watch(unitTemplatesProvider(unit.id)).value ??
                            [];
                        return ActionRow(
                          icon: Icons.mark_email_read_outlined,
                          title: 'Reading messages',
                          subtitle: templates.isEmpty
                              ? 'Teach the app to read messages for this unit'
                              : '${templates.length} rule${templates.length == 1 ? '' : 's'} · add or review',
                          onTap: () =>
                              context.push(Routes.manageRulesFor(unit.id)),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Recent activity',
                      style: AppTypography.headlineSm.copyWith(
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (unitTransactions.isEmpty)
                      const EmptyActivity()
                    else
                      GroupedList(
                        transactions: unitTransactions,
                        unitById: {unit.id: unit},
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
