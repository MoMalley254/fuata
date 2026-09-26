import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/logic/ledger.dart';
import 'package:fuata/ui/screens/rule_builder_screen.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../widgets/activity/empty_activity.dart';
import '../../widgets/activity/grouped_list.dart';
import '../../widgets/coming_soon_row.dart';
import '../../widgets/personalization/action_row.dart';
import '../../widgets/sheets/edit_unit_sheet.dart';
import '../../widgets/sheets/update_balance_sheet.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'manage_rules_screen.dart';

/// Unit page (ui-design-brief.md section 7.5): balance, "Update balance",
/// edit name/icon/colour, archive, and that unit's recent activity —
/// reusing GroupedList/showTransactionDetail from the Activity screen
/// rather than a second implementation.
///
/// The per-unit limit row is still a "coming soon" placeholder (#15/#17);
/// the message-reading row is live as of #20 — it opens the rule builder
/// pre-set to this unit and shows how many rules the unit already has.

class UnitDetailScreen extends ConsumerWidget {
  final String unitId;
  const UnitDetailScreen({super.key, required this.unitId});

  void _confirmArchive(BuildContext context, WidgetRef ref, String unitId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive $name?'),
        content: const Text(
          "It'll disappear from Home and My money, but its history stays safe.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(unitRepositoryProvider).archiveUnit(unitId);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unitsAsync = ref.watch(unitsProvider);
    final txAsync = ref.watch(transactionsProvider);

    return unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive(),),
        error: (e, st) => Center(child: Text('Something went wrong: $e'),),
        data: (units) {
          final unit = units.where((u) => u.id == unitId).firstOrNull;
          if (unit == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Text("This one's gone.", style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant)),
              ),
            );
          }

          return txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator.adaptive(),),
              error: (e, st) => Center(child: Text('Something went wrong: $e')),
              data: (allTransactions) {
                final balance = Ledger.balanceOf(unit, allTransactions);
                final unitTransactions = allTransactions
                    .where((t) => t.unitId == unit.id && t.isConfirmed)
                    .toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                return Scaffold(
                  appBar: AppBar(
                    title: Text(unit.name),
                    actions: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => showEditUnitSheet(context, existing: unit),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'archive') _confirmArchive(context, ref, unit.id, unit.name);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'archive', child: Text('Archive')),
                        ],
                      ),
                    ],
                  ),
                  body: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.xl),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: unit.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppSpacing.cardRadiusHero),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(unit.iconEmoji, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(unit.name, style: AppTypography.headlineSm.copyWith(color: c.onSurface)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                Money(balance, unit.currencyCode).format(),
                                style: AppTypography.displayHeroMobile.copyWith(color: c.onSurface),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                unit.lastVerifiedAt == null
                                    ? 'Not checked yet'
                                    : 'Last checked ${DateFormat('d MMM, h:mm a').format(unit.lastVerifiedAt!)}',
                                style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              FilledButton.tonal(
                                onPressed: () => showUpdateBalanceSheet(
                                  context,
                                  unit: unit,
                                  currentBalanceMinor: balance,
                                ),
                                child: const Text('Update balance'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const ComingSoonRow(
                          icon: Icons.speed_rounded,
                          title: 'Limit for this unit',
                          subtitle: 'Set a spending limit just for this one — coming in #15/#17',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Builder(
                          builder: (context) {
                            final templates =
                                ref.watch(unitTemplatesProvider(unit.id)).value ?? [];
                            return ActionRow(
                              icon: Icons.mark_email_read_outlined,
                              title: 'Reading messages',
                              subtitle: templates.isEmpty
                                  ? 'Teach the app to read messages for this unit'
                                  : '${templates.length} rule${templates.length == 1 ? '' : 's'} · add or review',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ManageRulesScreen(unitId: unit.id),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Recent activity', style: AppTypography.headlineSm.copyWith(color: c.onSurface)),
                        const SizedBox(height: AppSpacing.sm),
                        if (unitTransactions.isEmpty)
                          const EmptyActivity()
                        else
                          GroupedList(transactions: unitTransactions, unitById: {unit.id: unit}),

                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}