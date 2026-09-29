import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:intl/intl.dart';

import '../../domain/logic/ledger.dart';
import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../main.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../sheets/fix_captured_sheet.dart';
import '../sheets/update_balance_sheet.dart';

class PendingCard extends ConsumerWidget {
  final MoneyTransaction t;
  final MoneyUnit? unit;
  const PendingCard({super.key, required this.t, this.unit});

  List<MoneyTransaction> _childRows(List<MoneyTransaction> all) =>
      all.where((x) => x.parentId == t.id).toList();

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    List<MoneyTransaction> childRows,
  ) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.confirmTransaction(t.id);
    for (final child in childRows) {
      await repo.confirmTransaction(child.id);
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final unit = this.unit;
    if (t.balanceAfterMinor == null || unit == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to your money.')),
      );
      return;
    }

    // Reconcile (requirements.md section 5): if the balance the message
    // quoted disagrees with the ledger now that this row is in, flag it
    // and offer the adjustment entry immediately.
    final all = ref.read(transactionsProvider).value ?? [];
    final others = all.where(
      (x) => x.isConfirmed && x.id != t.id && x.parentId != t.id,
    );
    final computed =
        Ledger.balanceOf(unit, others) +
        t.amountMinor +
        childRows.fold<int>(0, (sum, x) => sum + x.amountMinor);
    if (t.balanceAfterMinor == computed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to your money.')),
      );
      return;
    }

    // Capture values before the snackbar — `unit` and `computed` are
    // immutables, so the closure below survives the PendingCard being
    // unmounted when confirmTransaction removes t from the pending list.
    final capturedUnit = unit;
    final capturedComputed = computed;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "The message says ${Money(t.balanceAfterMinor!, unit.currencyCode).format()}, "
          'but the ledger says ${Money(computed, unit.currencyCode).format()}.',
        ),
        action: SnackBarAction(
          label: 'Update balance',
          onPressed: () {
            ScaffoldMessenger.of(rootNavigatorKey.currentContext!)
                .hideCurrentSnackBar();
            showUpdateBalanceSheet(
              unit: capturedUnit,
              currentBalanceMinor: capturedComputed,
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<MoneyTransaction> childRows,
  ) async {
    final repo = ref.read(transactionRepositoryProvider);
    for (final child in childRows) {
      await repo.deleteTransaction(child.id);
    }
    await repo.deleteTransaction(t.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Removed.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unit = this.unit;
    final currency = unit?.currencyCode ?? 'KES';
    final isInflow = t.amountMinor >= 0;
    final childRows = _childRows(ref.watch(transactionsProvider).value ?? []);
    final feeMinor = childRows.fold<int>(
      0,
      (sum, x) => sum + x.amountMinor.abs(),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (unit?.color ?? c.primary).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unit?.iconEmoji ?? '💰',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isInflow ? 'Got' : 'Spent'} '
                      '${Money(t.amountMinor.abs(), currency).format()}'
                      '${feeMinor > 0 ? ' + ${Money(feeMinor, currency).format()} fee' : ''}',
                      style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                    ),
                    Text(
                      '${t.counterparty ?? unit?.name ?? 'Unknown'} · '
                      '${unit?.name ?? 'Unknown'} · '
                      '${DateFormat('d MMM, h:mm a').format(t.occurredAt)}',
                      style: AppTypography.bodySm.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _action(
                c: c,
                icon: Icons.check_rounded,
                label: 'Looks right',
                color: c.statusSafe,
                onTap: () => _confirm(context, ref, childRows),
              ),
              _action(
                c: c,
                icon: Icons.edit_outlined,
                label: 'Fix',
                color: c.onSurfaceVariant,
                onTap: () => showFixCapturedSheet(context, t),
              ),
              _action(
                c: c,
                icon: Icons.close_rounded,
                label: 'Not mine',
                color: c.onSurfaceVariant,
                onTap: () => _delete(context, ref, childRows),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action({
    required AppColors c,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: AppTypography.labelMd.copyWith(color: color)),
      ),
    );
  }
}
