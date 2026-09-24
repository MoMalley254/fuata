
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
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
      final day = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      groups.putIfAbsent(day, () => []).add(t);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
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
                    Text(
                      Money(netMinor, currency).format(showSign: true),
                      style: AppTypography.labelSm.copyWith(
                        color: netMinor >= 0 ? context.colors.statusSafe : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...dayTx.map((t) {
                final unit = unitById[t.unitId];
                return TransactionRow(
                  title: t.counterparty ?? unit?.name ?? 'Unknown',
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