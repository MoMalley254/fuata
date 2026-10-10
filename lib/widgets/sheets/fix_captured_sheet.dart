import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/models/unit.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import '../category_chip_row.dart';

/// Fix a captured transaction in place (the review inbox's ✎,
/// ui-design-brief.md 7.6): the fields the parser can realistically get
/// wrong — spent vs got, amount, who, which unit, when. Saves via
/// `updateTransaction`; the row stays pending and the balance stays
/// untouched until the person confirms it with Looks right.
Future<void> showFixCapturedSheet(
  BuildContext context,
  MoneyTransaction transaction,
) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FixCapturedSheet(transaction: transaction),
  );
}

class FixCapturedSheet extends ConsumerStatefulWidget {
  final MoneyTransaction transaction;
  const FixCapturedSheet({super.key, required this.transaction});

  @override
  ConsumerState<FixCapturedSheet> createState() => _FixCapturedSheetState();
}

class _FixCapturedSheetState extends ConsumerState<FixCapturedSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _counterpartyController;
  late TxType _type;
  late DateTime _occurredAt;
  late String? _unitId;
  bool _saving = false;
  String? _error;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    final units = ref.read(unitsProvider).value ?? [];
    final currency =
        units
            .where((u) => u.id == t.unitId)
            .map((u) => u.currencyCode)
            .firstOrNull ??
        'KES';
    _amountController = TextEditingController(
      text: Money(t.amountMinor.abs(), currency).format(),
    );
    _counterpartyController = TextEditingController(text: t.counterparty ?? '');
    _type = t.type == TxType.got ? TxType.got : TxType.spent;
    _occurredAt = t.occurredAt;
    _unitId = t.unitId;
    _categoryId = widget.transaction.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _counterpartyController.dispose();
    super.dispose();
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

  Future<void> _save(List<MoneyUnit> units) async {
    final unitId = _unitId;
    if (unitId == null) {
      setState(() => _error = 'Pick where this money is');
      return;
    }
    final unit = units.firstWhere((u) => u.id == unitId);

    late final Money amount;
    try {
      amount = Money.parseMajor(_amountController.text, unit.currencyCode);
    } on FormatException {
      setState(() => _error = "That amount doesn't look right");
      return;
    }
    if (amount.isZero) {
      setState(() => _error = 'Amount must be more than zero');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final t = widget.transaction;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .updateTransaction(
            MoneyTransaction(
              id: t.id,
              unitId: unit.id,
              type: _type,
              amountMinor: _type == TxType.got ? amount.minor : -amount.minor,
              counterparty: _counterpartyController.text.trim().isEmpty
                  ? null
                  : _counterpartyController.text.trim(),
              categoryId: _categoryId,
              note: t.note,
              code: t.code,
              occurredAt: _occurredAt,
              createdAt: t.createdAt,
              source: t.source,
              status: t.status, // stays pending until Looks right
              transferGroupId: t.transferGroupId,
              parentId: t.parentId,
              templateId: t.templateId,
              balanceAfterMinor: t.balanceAfterMinor,
              rawText: t.rawText,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _saving = false;
        _error = 'Could not save: $error';
      });
    }
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
      error: (e, st) => SizedBox(
        height: 200,
        child: Center(child: Text('Could not load your money: $e')),
      ),
      data: (units) {
        if (units.isEmpty) {
          return _SheetShell(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Add some money first — captures belong to a unit.',
                style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          );
        }
        if (_unitId == null || !units.any((u) => u.id == _unitId)) {
          _unitId = units.first.id;
        }

        return _SheetShell(
          child: Padding(
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
                  Text(
                    'Fix this one',
                    style: AppTypography.headlineSm.copyWith(
                      color: c.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppChoiceChip(
                        label: 'Spent',
                        selected: _type == TxType.spent,
                        onTap: () => setState(() => _type = TxType.spent),
                      ),
                      AppChoiceChip(
                        label: 'Got',
                        selected: _type == TxType.got,
                        onTap: () => setState(() => _type = TxType.got),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: 'Amount'),
                    style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _counterpartyController,
                    decoration: const InputDecoration(
                      hintText: 'Who or what for?',
                    ),
                    style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CategoryChipRow(
                    categories: ref.watch(categoriesProvider).value ?? const [],
                    selectedId: _categoryId,
                    onSelected: (id) => setState(() => _categoryId = id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Money',
                    style: AppTypography.labelMd.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: units.map((u) {
                      return AppChoiceChip(
                        label: '${u.iconEmoji} ${u.name}',
                        selected: u.id == _unitId,
                        onTap: () => setState(() => _unitId = u.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: _pickDateTime,
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: c.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          DateFormat('EEE, d MMM · h:mm a').format(_occurredAt),
                          style: AppTypography.bodyMd.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ],
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
                      onPressed: _saving ? null : () => _save(units),
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
          ),
        );
      },
    );
  }
}

/// The rounded, theme-aware modal shell shared by the sheets in this
/// folder (mirrors the Shell in add_transaction_sheet.dart).
class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

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

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
