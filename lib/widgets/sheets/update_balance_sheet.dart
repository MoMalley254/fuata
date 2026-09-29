import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// "Update balance" (ui-design-brief.md section 7.5): the user types the
/// true amount; the app records the DIFFERENCE as an adjustment entry
/// rather than overwriting anything (design.md field rules table —
/// balances are always derived from the ledger, never stored directly).
///
/// Uses flutter_smart_dialog rather than showModalBottomSheet because the
/// caller's BuildContext may be disposed by the time the sheet is opened
/// (the review inbox's PendingCard is unmounted the moment the row it
/// shows gets confirmed — see _confirm in pending_card.dart).
Future<void> showUpdateBalanceSheet({
  required MoneyUnit unit,
  required int currentBalanceMinor,
}) {
  return SmartDialog.show(
    alignment: Alignment.bottomCenter,
    clickMaskDismiss: true,
    animationType: SmartAnimationType.scale,
    builder: (_) => UpdateBalanceSheet(
      unit: unit,
      currentBalanceMinor: currentBalanceMinor,
    ),
  );
}

class UpdateBalanceSheet extends ConsumerStatefulWidget {
  final MoneyUnit unit;
  final int currentBalanceMinor;
  const UpdateBalanceSheet({
    super.key,
    required this.unit,
    required this.currentBalanceMinor,
  });

  @override
  ConsumerState<UpdateBalanceSheet> createState() => _UpdateBalanceSheetState();
}

class _UpdateBalanceSheetState extends ConsumerState<UpdateBalanceSheet> {
  late final _controller = TextEditingController(
    text: Money(widget.currentBalanceMinor, widget.unit.currencyCode).format(),
  );
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    late final Money trueBalance;
    try {
      trueBalance = Money.parseMajor(
        _controller.text,
        widget.unit.currencyCode,
      );
    } on FormatException {
      setState(() => _error = "That doesn't look like an amount");
      return;
    }

    final diff = trueBalance.minor - widget.currentBalanceMinor;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (diff != 0) {
        final now = DateTime.now();
        await ref
            .read(transactionRepositoryProvider)
            .addTransaction(
              MoneyTransaction(
                id: 'adj_${now.microsecondsSinceEpoch}',
                unitId: widget.unit.id,
                type: TxType.adjustment,
                amountMinor: diff,
                counterparty: 'Balance update',
                occurredAt: now,
                createdAt: now,
              ),
            );
      }
      await ref
          .read(unitRepositoryProvider)
          .updateUnit(widget.unit.copyWith(lastVerifiedAt: DateTime.now()));
      SmartDialog.dismiss();
    } catch (error) {
      setState(() {
        _saving = false;
        _error = 'Could not save: $error';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final symbol = currencySymbol(widget.unit.currencyCode);

    // SmartDialog renders outside the app's Scaffold/Material hierarchy,
    // so the sheet supplies its own Material + theme access.

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
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
                  Text(
                    'Update ${widget.unit.name}',
                    style: AppTypography.headlineSm.copyWith(
                      color: c.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "What's the true balance right now?",
                    style: AppTypography.bodySm.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(prefixText: symbol),
                    style: AppTypography.headlineLg.copyWith(
                      color: c.onSurface,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: AppTypography.bodySm.copyWith(
                        color: c.statusDanger,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
