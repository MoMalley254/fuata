import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/outing.dart';
import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import '../personalization/label.dart';
import '../personalization/toggle_row.dart';

/// Create or edit an outing (issue #30).
///
/// Defaults to "starts now, ends in 3 days at the same time" — the
/// most common shape of a short trip, and the person can change either
/// end with a picker. The amount is typed in the same way limits are.
class EditOutingSheet extends ConsumerStatefulWidget {
  const EditOutingSheet({super.key, this.existing});
  final Outing? existing;

  @override
  ConsumerState<EditOutingSheet> createState() => _EditOutingSheetState();
}

class _EditOutingSheetState extends ConsumerState<EditOutingSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money(widget.existing!.amountMinor, widget.existing!.currencyCode)
        .format()
        .replaceAll(',', ''),
  );
  late DateTime _startAt = widget.existing?.startAt ?? DateTime.now();
  late DateTime _endAt =
      widget.existing?.endAt ?? DateTime.now().add(const Duration(days: 3));
  late Set<String> _unitIds = widget.existing?.unitIds ?? const {};
  late bool _bannerEnabled = widget.existing?.bannerEnabled ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endAt.isAfter(_startAt)
          ? _endAt
          : _startAt.add(const Duration(days: 1)),
      firstDate: _startAt.add(const Duration(hours: 1)),
      lastDate: _startAt.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
    );
    if (time == null) return;
    setState(() {
      _endAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save(List<MoneyUnit> units) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }

    late final Money amount;
    final settings = ref.read(currentSettingsProvider);
    try {
      amount = Money.parseMajor(_amountController.text, settings.currencyCode);
    } on FormatException {
      setState(() => _error = "That doesn't look like an amount");
      return;
    }
    if (amount.minor <= 0) {
      setState(() => _error = 'Amount must be more than zero');
      return;
    }
    if (!_endAt.isAfter(_startAt)) {
      setState(() => _error = 'The end must be after the start');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final existing = widget.existing;
    final now = DateTime.now();
    final outing = Outing(
      id: existing?.id ?? 'outing_${now.microsecondsSinceEpoch}',
      name: name,
      amountMinor: amount.minor,
      currencyCode: settings.currencyCode,
      startAt: _startAt,
      endAt: _endAt,
      unitIds: _unitIds,
      bannerEnabled: _bannerEnabled,
      enabled: existing?.enabled ?? true,
      createdAt: existing?.createdAt ?? now,
    );

    try {
      await ref.read(outingRepositoryProvider).saveOuting(outing);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save, please try again';
      });
    }
  }

  Future<void> _endNow() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this outing now?'),
        content: const Text(
          "It won't show on the banner any more, and it won't nudge you. "
              "Your spending during it stays in your history.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(outingRepositoryProvider).endOutingNow(id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this outing?'),
        content: const Text(
          "The outing goes away. Your spending during it stays in your "
              "history — deleting an outing never deletes money.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(outingRepositoryProvider).deleteOuting(id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unitsAsync = ref.watch(unitsProvider);
    final settings = ref.watch(currentSettingsProvider);
    final symbol = currencySymbol(settings.currencyCode);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: unitsAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              "Couldn't load your units.",
              style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          data: (units) {
            final active = units.where((u) => !u.archived).toList();
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
                          borderRadius:
                          BorderRadius.circular(AppSpacing.pill),
                        ),
                      ),
                    ),
                    Text(
                      widget.existing == null
                          ? 'Plan an outing'
                          : 'Edit ${widget.existing!.name}',
                      style:
                      AppTypography.headlineSm.copyWith(color: c.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'What do you call it? e.g. Mombasa trip',
                      ),
                      style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: symbol,
                        hintText: 'Budget for the trip',
                      ),
                      style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DateTimeRow(
                      label: 'Starts',
                      at: _startAt,
                      onTap: _pickStart,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DateTimeRow(
                      label: 'Ends',
                      at: _endAt,
                      onTap: _pickEnd,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Label('Money from'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      active.isEmpty
                          ? 'Add some money first.'
                          : 'All of it, unless you pick specific units.',
                      style: AppTypography.bodySm
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppChoiceChip(
                          label: 'All',
                          selected: _unitIds.isEmpty,
                          onTap: () => setState(() => _unitIds = const {}),
                        ),
                        for (final u in active)
                          AppChoiceChip(
                            label: '${u.iconEmoji} ${u.name}',
                            selected: _unitIds.contains(u.id),
                            onTap: () => setState(() {
                              final next = {..._unitIds};
                              if (!next.remove(u.id)) next.add(u.id);
                              _unitIds = next;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ToggleRow(
                      title: 'Show on the banner',
                      subtitle:
                      'While the outing runs, the banner shows this '
                          'budget instead of your daily limit.',
                      value: _bannerEnabled,
                      onChanged: (v) =>
                          setState(() => _bannerEnabled = v),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _error!,
                        style: AppTypography.bodySm
                            .copyWith(color: c.statusDanger),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save(active),
                        child: _saving
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Text(widget.existing == null
                            ? 'Start outing'
                            : 'Save'),
                      ),
                    ),
                    if (widget.existing != null &&
                        widget.existing!.enabled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: _saving ? null : _endNow,
                          child: const Text('End now'),
                        ),
                      ),
                    ],
                    if (widget.existing != null) ...[
                      Center(
                        child: TextButton(
                          onPressed: _saving ? null : _delete,
                          child: Text(
                            'Delete',
                            style: AppTypography.labelMd
                                .copyWith(color: c.statusDanger),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.at,
    required this.onTap,
  });
  final String label;
  final DateTime at;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text(label, style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                DateFormat('EEE d MMM · h:mm a').format(at),
                textAlign: TextAlign.right,
                style: AppTypography.bodyMd.copyWith(color: c.onSurface),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}