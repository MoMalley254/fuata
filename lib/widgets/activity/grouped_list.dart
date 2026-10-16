
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../amount_text.dart';
import '../sheets/transaction_detail_sheet.dart';
import '../transaction_row.dart';


Future<void> showTransactionDetail(
    BuildContext context, {
      required MoneyTransaction transaction,
      required MoneyUnit? unit,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionDetailSheet(transaction: transaction, unit: unit),
  );
}

class GroupedList extends StatelessWidget {
  final List<MoneyTransaction> transactions;
  final Map<String, MoneyUnit> unitById;
  const GroupedList({super.key, required this.transactions, required this.unitById});

  String _dayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<MoneyTransaction>>{};
    for (final t in transactions) {
      // Issue #109: group by the *local* calendar day. An occurredAt
      // stored as UTC (the parser's ISO branch, a backup import) would
      // otherwise key on its UTC calendar day, and a payment made at
      // 02:00 local in EAT (23:00 UTC the day before) would land under
      // yesterday's header.
      final local = t.occurredAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => []).add(t);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
        shrinkWrap: true,
        // physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.xl,
        ),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          final dayTx = groups[day]!;
          final currency = dayTx.isNotEmpty ? unitById[dayTx.first.unitId]?.currencyCode ?? 'KES' : 'KES';
          final netMinor = dayTx
              .where((t) => t.type == TxType.spent || t.type == TxType.got)
              .fold(0, (sum, t) => sum + t.amountMinor);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dayHeader(day), style: AppTypography.labelMd.copyWith(color: context.colors.onSurfaceVariant)),
                    AmountText(
                      minor: netMinor,
                      currencyCode: currency,
                      showSign: true,
                      style: AppTypography.labelSm.copyWith(
                        color: netMinor >= 0
                            ? context.colors.statusSafe
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...dayTx.map((t) {
                final unit = unitById[t.unitId];
                return TransactionRow(
                  // `?.displayName` appends "(archived)" once the unit has been put
                  // away, so a row's title still reads as the unit it belongs to
                  // rather than "Unknown".
                  title: t.counterparty ?? unit?.displayName ?? 'Unknown',
                  subtitle: DateFormat('h:mm a').format(t.occurredAt),
                  amount: Money(t.amountMinor, unit?.currencyCode ?? 'KES').majorValue,
                  emoji: unit?.iconEmoji ?? '💰',
                  accent: unit?.color,
                  onTap: () => showTransactionDetail(context, transaction: t, unit: unit),
                );
              }),
              const SizedBox(height: AppSpacing.sm,),
            ],
          );
        }
    );
  }
}