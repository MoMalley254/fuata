import 'package:flutter/material.dart';

import '../../widgets/app_chips.dart';
import '../../widgets/status_ring_card.dart';
import '../../widgets/transaction_row.dart';
import '../../widgets/unit_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_status.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onToggleMode});
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            onPressed: onToggleMode,
            icon: const Icon(Icons.brightness_6_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          const Padding(
            padding: kScreenInset,
            child: StatusRingCard(
              remaining: 1500,
              spent: 4250,
              limit: 6000,
              status: BudgetStatus.safe,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: kScreenInset,
              children: const [
                UnitCard(unit: MoneyUnit.cash, title: 'Cash', balance: 760, emoji: '💵'),
                SizedBox(width: AppSpacing.gutterSm),
                UnitCard(unit: MoneyUnit.mobileMoney, title: 'Mobile', balance: 3450, emoji: '📱'),
                SizedBox(width: AppSpacing.gutterSm),
                UnitCard(unit: MoneyUnit.bank, title: 'Bank', balance: 12000, emoji: '🏦'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: kScreenInset,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppChoiceChip(label: 'All', selected: true, onTap: () {}),
                AppChoiceChip(label: 'Spent', selected: false, onTap: () {}),
                AppChoiceChip(label: 'Got', selected: false, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Padding(
            padding: kScreenInset,
            child: Column(
              children: [
                TransactionRow(
                  title: 'Java House',
                  subtitle: 'Today · 09:12',
                  amount: -350,
                  emoji: '☕',
                ),
                SizedBox(height: AppSpacing.sm),
                TransactionRow(
                  title: 'Salary',
                  subtitle: 'Yesterday',
                  amount: 5000,
                  emoji: '💰',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: kScreenInset,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                WordLabelChip(word: 'M-PESA', assignedField: 'Payee'),
                WordLabelChip(word: '350.00', assignedField: 'Amount'),
                WordLabelChip(word: 'Fee'),
                WordLabelChip(word: 'Confirmed.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}