import 'package:flutter/material.dart';
import 'package:fuata/domain/models/money.dart';
import 'package:intl/intl.dart';

import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';

// ---------------------------------------------------------------------------
// Transaction detail sheet, shown at Simple / Balanced / Detailed levels
// (ui-design-brief.md sections 3 and 7.4). A per-settings default detail
// level is issue #12's job; this sheet carries its own local toggle so the
// three levels can be seen and used today.
// ---------------------------------------------------------------------------

enum _DetailLevel { simple, balanced, detailed }

class TransactionDetailSheet extends StatefulWidget {
  final MoneyTransaction transaction;
  final MoneyUnit? unit;
  const TransactionDetailSheet({super.key, required this.transaction, required this.unit});

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  _DetailLevel _level = _DetailLevel.balanced;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = widget.transaction;
    final unit = widget.unit;
    final currency = unit?.currencyCode ?? 'KES';
    final amount = Money(t.amountMinor.abs(), currency);
    final isInflow = t.amountMinor >=0;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadiusHero)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
Center(
  child: Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    decoration: BoxDecoration(
      color: c.outlineVariant,
      borderRadius: BorderRadius.circular(AppSpacing.pill),
    ),
  ),
),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (unit?.color ?? c.primary).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(unit?.iconEmoji ?? '💰', style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.counterparty ?? unit?.name ?? 'Unknown',
                        style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                      ),
                      Text(
                        DateFormat('EEEE, d MMM · h:mm a').format(t.occurredAt),
                        style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${isInflow ? '+' : '-'}${amount.format()}',
              style: AppTypography.headlineLg.copyWith(
                color: isInflow ? c.statusSafe : c.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md,),
            Row(
              children: _DetailLevel.values.map((lvl) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppChoiceChip(
                    label: switch (lvl) {
                      _DetailLevel.simple => 'Simple',
                      _DetailLevel.balanced => 'Balanced',
                      _DetailLevel.detailed => 'Detailed',
                    },
                    selected: _level == lvl,
                    onTap: () => setState(() => _level = lvl),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            ...detailRows(context),
          ],
        ),
      ),
    );
  }

  List<Widget> detailRows(BuildContext context) {
    final t = widget.transaction;
    final unit = widget.unit;
    final rows = <MapEntry<String, String>>[];

    // Simple: nothing extra — title/time/amount above is already the
    // whole story.
    if (_level == _DetailLevel.simple) return const [];

    // Balanced: unit and a friendly type label.
    rows.add(MapEntry('Money', unit?.name ?? 'Unknown'));
    rows.add(MapEntry('Type', switch (t.type) {
      TxType.spent => 'Spent',
      TxType.got => 'Got',
      TxType.moved => 'Moved',
      TxType.adjustment => 'Balance update',
    }));

    if (_level == _DetailLevel.detailed) {
      rows.add(MapEntry('Exact time', DateFormat('d MMM yyyy, h:mm:ss a').format(t.occurredAt)));
      if (t.code != null) rows.add(MapEntry('Code', t.code!));
      if (t.transferGroupId != null) rows.add(const MapEntry('Transfer', 'Linked to another entry'));
      if (t.parentId != null) rows.add(MapEntry('Fee for', t.parentId!));
      if (t.note != null) rows.add(MapEntry('Note', t.note!));
      rows.add(MapEntry('Added via', switch (t.source) {
        TxSource.manual => 'Typed in',
        TxSource.shared => 'Shared message',
        TxSource.notification => 'Caught from a notification',
      }));
      if (t.balanceAfterMinor != null) {
        rows.add(MapEntry(
          'Balance after (reported)',
          Money(t.balanceAfterMinor!, unit?.currencyCode ?? 'KES').format(),
        ));
      }
    }

    final c = context.colors;
    return rows
        .map((e) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(e.key, style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant)),
          Flexible(
            child: Text(
              e.value,
              textAlign: TextAlign.right,
              style: AppTypography.bodySm.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    ))
        .toList();
  }
}
