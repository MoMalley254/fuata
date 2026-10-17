import 'package:flutter/material.dart';

import '../../domain/logic/onboarding.dart';
import '../../domain/models/money.dart';
import '../../domain/models/unit.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/label.dart';
import 'step_frame.dart';

/// What each quick-pick tile starts from (ui-design-brief.md 7.1 step 2).
class KindDefaults {
  const KindDefaults({
    required this.kind,
    required this.label,
    required this.emoji,
    required this.name,
  });

  final UnitKind kind;

  /// The tile's caption.
  final String label;
  final String emoji;

  /// Pre-filled into the name field; empty for "Something else".
  final String name;

  /// The colour a new unit of this kind starts with.
  Color color(AppColors c) => switch (kind) {
    UnitKind.cash => c.unitCash,
    UnitKind.mobileMoney => c.unitMobileMoney,
    UnitKind.bank => c.unitBank,
    UnitKind.card => c.unitCard,
    UnitKind.other => c.secondary,
  };
}

const kindQuickPicks = <KindDefaults>[
  KindDefaults(kind: UnitKind.cash, label: 'Cash', emoji: '💵', name: 'Cash'),
  KindDefaults(
    kind: UnitKind.mobileMoney,
    label: 'Mobile money',
    emoji: '📱',
    name: 'Mobile money',
  ),
  KindDefaults(kind: UnitKind.bank, label: 'Bank', emoji: '🏦', name: 'Bank'),
  KindDefaults(kind: UnitKind.card, label: 'Card', emoji: '💳', name: 'Card'),
  KindDefaults(
    kind: UnitKind.other,
    label: 'Something else',
    emoji: '👛',
    name: '',
  ),
];

const _emojiOptions = ['💵', '📱', '🏦', '💳', '👛', '💰', '🏧', '💷', '💶', '🐷'];

/// The tiny sheet a quick-pick tile opens: name, icon, colour and "how much
/// is in it now?". Nothing is saved here — [onSave] hands the finished unit
/// back to the onboarding draft. Pass [existing] to edit a unit already in
/// the draft (and [onRemove] to offer removing it).
Future<void> showUnitDraftSheet(
  BuildContext context, {
  required KindDefaults defaults,
  MoneyUnit? existing,
  required ValueChanged<MoneyUnit> onSave,
  VoidCallback? onRemove,
  required String currencyCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UnitDraftSheet(
      defaults: defaults,
      existing: existing,
      onSave: onSave,
      onRemove: onRemove,
      currencyCode: currencyCode,
    ),
  );
}

class _UnitDraftSheet extends StatefulWidget {
  const _UnitDraftSheet({
    required this.defaults,
    required this.existing,
    required this.onSave,
    required this.onRemove,
    required this.currencyCode,
  });

  final KindDefaults defaults;
  final MoneyUnit? existing;
  final ValueChanged<MoneyUnit> onSave;
  final VoidCallback? onRemove;
  final String currencyCode;

  @override
  State<_UnitDraftSheet> createState() => _UnitDraftSheetState();
}

class _UnitDraftSheetState extends State<_UnitDraftSheet> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.defaults.name,
  );
  late final _opening = TextEditingController(
    text: _initialOpening(widget.existing),
  );
  late String _emoji = widget.existing?.iconEmoji ?? widget.defaults.emoji;
  Color? _color;
  String? _error;

  static String _initialOpening(MoneyUnit? u) {
    if (u == null || u.openingBalanceMinor == 0) return '';
    return Money(u.openingBalanceMinor, u.currencyCode)
        .format()
        .replaceAll(',', '');
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save(AppColors c) {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }

    var openingMinor = 0;
    final text = _opening.text.trim();
    if (text.isNotEmpty) {
      try {
        openingMinor = Money.parseMajor(text, widget.currencyCode).minor;
      } on FormatException {
        setState(() => _error = "That doesn't look like an amount");
        return;
      }
      if (openingMinor < 0) {
        setState(() => _error = 'Enter zero or more');
        return;
      }
    }

    final existing = widget.existing;
    final now = DateTime.now();
    widget.onSave(
      MoneyUnit(
        id: existing?.id ?? 'unit_${now.microsecondsSinceEpoch}',
        name: name,
        kind: widget.defaults.kind,
        currencyCode: widget.currencyCode,
        iconEmoji: _emoji,
        color: _color ?? widget.defaults.color(c),
        openingBalanceMinor: openingMinor,
        // Same ordering rule as the unit sheet: creation time, so units
        // appear in the order they were added.
        sortOrder: existing?.sortOrder ?? now.microsecondsSinceEpoch,
        createdAt: existing?.createdAt ?? now,
      ),
    );
    Navigator.of(context).pop();
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
    final color = _color ?? widget.defaults.color(c);

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
                  widget.existing == null
                      ? 'Add ${widget.defaults.label.toLowerCase()}'
                      : 'Edit ${widget.existing!.name}',
                  style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'What do you call it?',
                  ),
                  style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                const Label('Icon'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final e in _emojiOptions)
                      InkWell(
                        onTap: () => setState(() => _emoji = e),
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _emoji == e
                                ? c.primary.withValues(alpha: 0.15)
                                : c.surfaceContainer,
                            border: Border.all(
                              color: _emoji == e ? c.primary : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(e, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Label('Colour'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final swatch in palette)
                      InkWell(
                        onTap: () => setState(() => _color = swatch),
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: swatch,
                            border: Border.all(
                              color: color.toARGB32() == swatch.toARGB32()
                                  ? c.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'How much is in it now? (optional)',
                  ),
                  style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.sm),
                const ReassuranceNote(
                  icon: Icons.lock_outline_rounded,
                  text: 'We never ask for account or card numbers.',
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
                    onPressed: () => _save(c),
                    child: Text(widget.existing == null ? 'Add' : 'Save'),
                  ),
                ),
                if (widget.onRemove != null)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        widget.onRemove!();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Remove'),
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
