import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/models/unit.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:fuata/widgets/provider_error_card.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../routing/routes.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import '../category_chip_row.dart';

/// Opens the add-transaction sheet. Wraps the real route so callers keep
/// the one-line API: /add is a deep-linkable, back-button-aware route now
/// (issue-26 F1), not a raw modal.
Future<void> showAddTransactionSheet(
  BuildContext context, {
  String? initialUnitId,
}) {
  return context.push(Routes.addFor(initialUnitId));
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  final String? initialUnitId;
  const AddTransactionSheet({super.key, required this.initialUnitId});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  TxType _type = TxType.spent;
  String _amountInput = ''; // raw digits/decimal as typed, e.g. "1250.50"
  String? _fromUnitId;
  String? _toUnitId;
  final _counterpartyController = TextEditingController();
  final _noteController = TextEditingController();
  final _feeController = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  bool _moreExpanded = false;
  bool _saving = false;
  String? _error;
  String? _categoryId;

  void _tapDigit(String d) {
    setState(() {
      if (d == '.' && _amountInput.contains('.')) return;
      // Cap at 2 decimal places once a '.' is present.
      final dotIndex = _amountInput.indexOf('.');
      if (dotIndex != -1 && _amountInput.length - dotIndex > 2) return;
      _amountInput += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_amountInput.isEmpty) return;
    setState(
      () => _amountInput = _amountInput.substring(0, _amountInput.length - 1),
    );
  }

  @override
  void initState() {
    super.initState();
    _fromUnitId = widget.initialUnitId;
  }

  @override
  void dispose() {
    _counterpartyController.dispose();
    _noteController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unitsAsync = ref.watch(unitsProvider);

    return unitsAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: CircularProgressIndicator.adaptive(),
      ),
      error: (e, st) => ProviderErrorCard(
        headline: "Couldn't load your money right now",
        error: e,
        onRetry: () => ref.invalidate(unitsProvider),
      ),
      data: (units) {
        if (units.isEmpty) {
          return Sheet(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Add some money first, then come back to record a transaction.',
                style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          );
        }
        _fromUnitId ??= units.first.id;
        return Sheet(child: buildContent(context, units));
      },
    );
  }

  Widget buildContent(BuildContext context, List<MoneyUnit> units) {
    final c = context.colors;
    final currency = units.first.currencyCode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
            TypeToggle(
              type: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            AmountDisplay(
              input: _amountInput,
              currencySymbol: currencySymbol(currency),
            ),
            const SizedBox(height: AppSpacing.md),
            Keypad(onDigit: _tapDigit, onBackspace: _backspace),
            const SizedBox(height: AppSpacing.lg),
            if (_type == TxType.moved)
              TransferUnitPickers(
                units: units,
                fromUnitId: _fromUnitId,
                toUnitId: _toUnitId,
                onFromChanged: (id) => setState(() => _fromUnitId = id),
                onToChanged: (id) => setState(() => _toUnitId = id),
              )
            else
              UnitChips(
                units: units,
                selectedId: _fromUnitId,
                onSelected: (id) => setState(() => _fromUnitId = id),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _counterpartyController,
              decoration: const InputDecoration(hintText: 'Who or what for?'),
              style: AppTypography.bodyLg.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            CategoryChipRow(
              categories: ref.watch(categoriesProvider).value ?? const [],
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: AppSpacing.sm),
            MoreSection(
              expanded: _moreExpanded,
              onToggle: () => setState(() => _moreExpanded = !_moreExpanded),
              occurredAt: _occurredAt,
              onPickDateTime: _pickDateTime,
              noteController: _noteController,
              feeController: _feeController,
              currencySymbol: currencySymbol(currency),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.bodySm.copyWith(color: c.statusDanger),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(units, currency),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save(List<MoneyUnit> units, String currency) async {
    if (_amountInput.isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    late final Money amount;
    try {
      amount = Money.parseMajor(_amountInput, currency);
    } on FormatException {
      setState(() => _error = "That amount doesn't look right");
      return;
    }
    if (amount.isZero) {
      setState(() => _error = 'Amount must be more than zero');
      return;
    }
    if (_fromUnitId == null) {
      setState(() => _error = 'Pick where this money is');
      return;
    }
    if (_type == TxType.moved &&
        (_toUnitId == null || _toUnitId == _fromUnitId)) {
      setState(() => _error = 'Pick two different units to move between');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(transactionRepositoryProvider);
    final now = DateTime.now();
    final baseId = 'tx_${now.microsecondsSinceEpoch}';
    final counterparty = _counterpartyController.text.trim().isEmpty
        ? null
        : _counterpartyController.text.trim();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    try {
      if (_type == TxType.moved) {
        final groupId = 'g_${now.microsecondsSinceEpoch}';
        await repo.addTransaction(
          MoneyTransaction(
            id: '${baseId}_out',
            unitId: _fromUnitId!,
            type: TxType.moved,
            amountMinor: -amount.minor,
            counterparty: counterparty ?? 'Moved',
            categoryId: _categoryId,
            note: note,
            occurredAt: _occurredAt,
            createdAt: now,
            transferGroupId: groupId,
          ),
        );
        await repo.addTransaction(
          MoneyTransaction(
            id: '${baseId}_in',
            unitId: _toUnitId!,
            type: TxType.moved,
            amountMinor: amount.minor,
            counterparty: counterparty ?? 'Moved',
            categoryId: _categoryId,
            note: note,
            occurredAt: _occurredAt,
            createdAt: now,
            transferGroupId: groupId,
          ),
        );
      } else {
        final signed = _type == TxType.spent ? -amount.minor : amount.minor;
        await repo.addTransaction(
          MoneyTransaction(
            id: baseId,
            unitId: _fromUnitId!,
            type: _type,
            amountMinor: signed,
            counterparty: counterparty,
            categoryId: _categoryId,
            note: note,
            occurredAt: _occurredAt,
            createdAt: now,
          ),
        );

        // Fee is its own child `spent` row, counted in spending automatically
        // (design.md ADR-005).
        final feeText = _feeController.text.trim();
        if (feeText.isNotEmpty) {
          try {
            final fee = Money.parseMajor(feeText, currency);
            if (!fee.isZero) {
              await repo.addTransaction(
                MoneyTransaction(
                  id: '${baseId}_fee',
                  unitId: _fromUnitId!,
                  type: TxType.spent,
                  amountMinor: -fee.minor.abs(),
                  counterparty: 'Fee',
                  categoryId: _categoryId,
                  occurredAt: _occurredAt,
                  createdAt: now,
                  parentId: baseId,
                ),
              );
            }
          } on FormatException {
            // Bad fee input is ignored rather than blocking the save —
            // the main transaction still matters more than the fee.
          }
        }
      }

      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          // Shouldn't happen after the nesting fix, but never leave the
          // person on an empty navigator.
          context.go(Routes.homePath);
        }
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save, please try again';
      });
    }
  }
}

class Sheet extends StatelessWidget {
  final Widget child;
  const Sheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
        child: child,
      ),
    );
  }
}

class TypeToggle extends StatelessWidget {
  final TxType type;
  final ValueChanged<TxType> onChanged;
  const TypeToggle({super.key, required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        chip('Spent', TxType.spent),
        const SizedBox(width: AppSpacing.sm),
        chip('Got', TxType.got),
        const SizedBox(width: AppSpacing.sm),
        chip('Moved', TxType.moved),
      ],
    );
  }

  Widget chip(String label, TxType value) {
    return Expanded(
      child: AppChoiceChip(
        label: label,
        selected: type == value,
        onTap: () => onChanged(value),
      ),
    );
  }
}

class AmountDisplay extends StatelessWidget {
  final String input;
  final String currencySymbol;
  const AmountDisplay({
    super.key,
    required this.input,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final display = input.isEmpty ? '0' : input;
    return Center(
      child: Text(
        '$currencySymbol$display',
        style: AppTypography.displayHero.copyWith(color: c.onSurface),
      ),
    );
  }
}

class Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const Keypad({super.key, required this.onDigit, required this.onBackspace});

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: _keys.map((k) {
        return InkWell(
          onTap: () => k == '⌫' ? onBackspace() : onDigit(k),
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: Center(
            child: Text(
              k,
              style: AppTypography.numericKeypad.copyWith(color: c.onSurface),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class UnitChips extends StatelessWidget {
  final List<MoneyUnit> units;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  const UnitChips({
    super.key,
    required this.units,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: units.map((u) {
        return AppChoiceChip(
          label: '${u.iconEmoji} ${u.name}',
          selected: u.id == selectedId,
          onTap: () => onSelected(u.id),
        );
      }).toList(),
    );
  }
}

class TransferUnitPickers extends StatelessWidget {
  final List<MoneyUnit> units;
  final String? fromUnitId;
  final String? toUnitId;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  const TransferUnitPickers({
    super.key,
    required this.units,
    required this.fromUnitId,
    required this.toUnitId,
    required this.onFromChanged,
    required this.onToChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'From',
          style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        UnitChips(
          units: units,
          selectedId: fromUnitId,
          onSelected: onFromChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        Icon(Icons.arrow_downward_rounded, color: c.onSurfaceVariant, size: 18),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'To',
          style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        UnitChips(
          units: units.where((u) => u.id != fromUnitId).toList(),
          selectedId: toUnitId,
          onSelected: onToChanged,
        ),
      ],
    );
  }
}

class MoreSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final DateTime occurredAt;
  final VoidCallback onPickDateTime;
  final TextEditingController noteController;
  final TextEditingController feeController;
  final String currencySymbol;

  const MoreSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.occurredAt,
    required this.onPickDateTime,
    required this.noteController,
    required this.feeController,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Text(
                'More',
                style: AppTypography.labelMd.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: c.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onPickDateTime,
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: c.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  DateFormat('EEE, d MMM · h:mm a').format(occurredAt),
                  style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: feeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Fee ($currencySymbol, optional)',
            ),
            style: AppTypography.bodyMd.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
            style: AppTypography.bodyMd.copyWith(color: c.onSurface),
          ),
        ],
      ],
    );
  }
}
