import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';

/// Create a unit, or edit an existing one's name/icon/colour
/// (ui-design-brief.md section 7.5: "edit name/icon/colour" is a separate
/// action from "Update balance" — kind and currency are fixed at creation,
/// matching MoneyUnit, which has no way to change them after the fact).
///
/// Simplification, flagged rather than silently done: currency defaults to
/// KES with no picker in v0.1 (see design.md ADR — overall limits are
/// single-currency for now). Multi-currency unit creation is future work.
Future<void> showEditUnitSheet(BuildContext context, {MoneyUnit? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditUnitSheet(existing: existing),
  );
}

const _kindOptions = [
  (UnitKind.cash, '💵', 'Cash'),
  (UnitKind.mobileMoney, '📱', 'Mobile money'),
  (UnitKind.bank, '🏦', 'Bank'),
  (UnitKind.card, '💳', 'Card'),
  (UnitKind.other, '👛', 'Other'),
];

const _emojiOptions = [
  '💵',
  '📱',
  '🏦',
  '💳',
  '👛',
  '💰',
  '🏧',
  '💷',
  '💶',
  '🐷',
];

class EditUnitSheet extends ConsumerStatefulWidget {
  final MoneyUnit? existing;
  const EditUnitSheet({super.key, this.existing});

  @override
  ConsumerState<EditUnitSheet> createState() => _EditUnitSheetState();
}

class _EditUnitSheetState extends ConsumerState<EditUnitSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _openingController = TextEditingController();
  late UnitKind _kind = widget.existing?.kind ?? UnitKind.cash;
  late String _emoji = widget.existing?.iconEmoji ?? _emojiOptions.first;
  late Color? _color = widget.existing?.color;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(unitRepositoryProvider);

    try {
      if (_isEdit) {
        await repo.updateUnit(
          widget.existing!.copyWith(
            name: name,
            iconEmoji: _emoji,
            color: _color,
          ),
        );
      } else {
        int openingMinor = 0;
        final openingText = _openingController.text.trim();
        if (openingText.isNotEmpty) {
          final parsed = double.tryParse(openingText.replaceAll(',', '')) ?? 0;
          openingMinor = (parsed * 100).round(); // KES-only in v0.1, 2dp
        }
        final now = DateTime.now();
        await repo.addUnit(
          MoneyUnit(
            id: 'unit_${now.microsecondsSinceEpoch}',
            name: name,
            kind: _kind,
            currencyCode: 'KES',
            iconEmoji: _emoji,
            color: _color!,
            openingBalanceMinor: openingMinor,
            sortOrder: now.microsecondsSinceEpoch,
            createdAt: now,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _saving = false;
        _error = 'Could not save, please try again';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final palette = [
      c.unitCash,
      c.unitMobileMoney,
      c.unitBank,
      c.unitCard,
      c.secondary,
      c.primary,
      c.statusWarning,
      c.statusDanger,
    ];
    _color ??= palette.first;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
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
                  _isEdit ? 'Edit ${widget.existing!.name}' : 'Add some money',
                  style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'What do you call it?',
                  ),
                  style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_isEdit) ...[
                  Text(
                    'Kind',
                    style: AppTypography.labelMd.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _kindOptions.map((opt) {
                      final (kind, emoji, label) = opt;
                      return AppChoiceChip(
                        label: '$emoji $label',
                        selected: _kind == kind,
                        onTap: () => setState(() => _kind = kind),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  'Icon',
                  style: AppTypography.labelMd.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _emojiOptions.map((e) {
                    final selected = _emoji == e;
                    return InkWell(
                      onTap: () => setState(() => _emoji = e),
                      borderRadius: BorderRadius.circular(AppSpacing.pill),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? c.primary.withValues(alpha: 0.15)
                              : c.surfaceContainer,
                          border: Border.all(
                            color: selected ? c.primary : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Colour',
                  style: AppTypography.labelMd.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: palette.map((swatch) {
                    final selected = _color!.toARGB32() == swatch.toARGB32();
                    return InkWell(
                      onTap: () => setState(() => _color = swatch),
                      borderRadius: BorderRadius.circular(AppSpacing.pill),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: swatch,
                          border: Border.all(
                            color: selected ? c.onSurface : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _openingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'How much is in it now? (optional)',
                    ),
                    style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                  ),
                ],
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
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_isEdit ? 'Save' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
