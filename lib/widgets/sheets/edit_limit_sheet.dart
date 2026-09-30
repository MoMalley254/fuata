import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

Future<void> showEditLimitSheet({
  required LimitPeriod period,
  required String currencyCode,
  LimitRule? existing,
}) async {
  return await SmartDialog.show(
    alignment: Alignment.bottomCenter,
    clickMaskDismiss: true,
    animationType: SmartAnimationType.scale,
    builder: (_) => EditLimitSheet(
      period: period,
      currencyCode: currencyCode,
      existing: existing,
    ),
  );
}

Future<bool?> showRemoveLimitDialog({
  required String title,
}) async {
  return await SmartDialog.show<bool>(
    clickMaskDismiss: true,
    builder: (_) => AlertDialog(
      title: Text('Remove the $title?'.toLowerCase()),
      content: const Text(
        'The banner will go back to just showing what you spent today.',
      ),
      actions: [
        TextButton(
          onPressed: () => SmartDialog.dismiss(result: false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => SmartDialog.dismiss(result: true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}

class EditLimitSheet extends ConsumerStatefulWidget {
  final LimitPeriod period;
  final String currencyCode;
  final LimitRule? existing;

  const EditLimitSheet({
    super.key,
    required this.period,
    required this.currencyCode,
    this.existing,
  });

  @override
  ConsumerState<EditLimitSheet> createState() => _EditLimitSheetState();
}

class _EditLimitSheetState extends ConsumerState<EditLimitSheet> {
  late final _controller = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money(widget.existing!.amountMinor, widget.currencyCode)
        .format()
        .replaceAll(',', ''),
  );
  bool _saving = false;
  String? _error;

  String get _title => switch (widget.period) {
    LimitPeriod.day => 'Daily limit',
    LimitPeriod.week => 'Weekly limit',
    LimitPeriod.month => 'Monthly limit',
  };

  Future<void> _save() async {
    late final Money amount;
    try {
      amount = Money.parseMajor(_controller.text, widget.currencyCode);
    } on FormatException {
      setState(() => _error = "That doesn't look like an amount");
      return;
    }
    if (amount.minor <= 0) {
      setState(() => _error = 'Amount must be more than zero');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final existing = widget.existing;
    // A brand-new limit starts with the alert levels already chosen for
    // the others (#63), not a hard-coded 70/90.
    final (warn, danger) = LimitRule.levelsFrom(
      ref.read(limitsProvider).value ?? const <LimitRule>[],
    );
    final rule = LimitRule(
      id: existing?.id ?? 'l_overall_${widget.period.name}',
      scope: LimitScope.overall,
      period: widget.period,
      amountMinor: amount.minor,
      currencyCode: widget.currencyCode,
      warnAt: existing?.warnAt ?? warn,
      dangerAt: existing?.dangerAt ?? danger,
      enabled: existing?.enabled ?? true,
    );

    try {
      await ref.read(limitRepositoryProvider).setLimit(rule);
      if (mounted) SmartDialog.dismiss();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
    }
  }

  Future<void> _remove() async {
    final id = widget.existing?.id;
    if (id == null) return;

    final confirmed = await showRemoveLimitDialog(title: _title);

    if (confirmed != true) return;

    await ref.read(limitRepositoryProvider).deleteLimit(id);
    if (mounted) SmartDialog.dismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final symbol = currencySymbol(widget.currencyCode);

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
                    _title,
                    style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'How much would you like to keep to?',
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
                    style: AppTypography.headlineLg.copyWith(color: c.onSurface),
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
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Save'),
                    ),
                  ),
                  if (widget.existing != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _saving ? null : _remove,
                        child: Text(
                          'Remove limit',
                          style: AppTypography.labelMd
                              .copyWith(color: c.statusDanger),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}