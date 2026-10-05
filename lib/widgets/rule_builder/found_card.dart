import 'package:flutter/material.dart';
import 'package:fuata/domain/logic/parser.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/template.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';

/// "Here's what I found": the extracted fields as a mini transaction
/// card. Fields the template doesn't label are shown as empty dashed
/// chips (ui-design-brief.md 7.7 step 3), so the person can see at a
/// glance what's still missing. #72: a field that *is* labelled but whose
/// text couldn't be read as that kind of value (see
/// [ParsedFields.unreadable]) gets its own "Couldn't read ..." state, so
/// it never looks like a field the person forgot to label.
class FoundCard extends StatelessWidget {
  final ParsedFields fields;
  final String currencyCode;
  const FoundCard({super.key, required this.fields, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final c= context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldRow(c, 'Amount', Money(fields.amountMinor!, currencyCode).format(),
              WordLabelChip.fieldTint('Amount', c)),
          _fieldRow(c, 'Payee', fields.counterparty,
              WordLabelChip.fieldTint('Payee', c)),
          _fieldRow(
            c,
            'When',
            fields.occurredAt == null
                ? null
                : DateFormat('d MMM yyyy, h:mm a').format(fields.occurredAt!),
            WordLabelChip.fieldTint('When', c),
            unreadable: _couldntRead(TemplateFieldType.date, 'a date'),
          ),
          _fieldRow(c, 'Code', fields.code, WordLabelChip.fieldTint('Code', c)),
          _fieldRow(
            c,
            'Fee',
            fields.feeMinor == null ? null : Money(fields.feeMinor!, currencyCode).format(),
            WordLabelChip.fieldTint('Fee', c),
            unreadable: _couldntRead(TemplateFieldType.fee, 'an amount'),
          ),
          _fieldRow(
            c,
            'Balance',
            fields.balanceAfterMinor == null
                ? null
                : Money(fields.balanceAfterMinor!, currencyCode).format(),
            WordLabelChip.fieldTint('Balance', c),
            unreadable: _couldntRead(TemplateFieldType.balance, 'an amount'),
          ),
        ],
      ),
    );
  }

  /// "Couldn't read '28-09-2026 11:03 PM' as a date", or null when the
  /// field wasn't labelled-but-unreadable.
  String? _couldntRead(TemplateFieldType type, String kind) {
    final raw = fields.unreadable[type];
    return raw == null ? null : "Couldn't read '$raw' as $kind";
  }

  Widget _fieldRow(
    AppColors c,
    String name,
    String? value,
    Color tint, {
    String? unreadable,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              name,
              style: AppTypography.labelSm.copyWith(color: tint),
            ),
          ),
          Expanded(
            child: value == null && unreadable != null
                ? Text(
                    unreadable,
                    style: AppTypography.bodySm.copyWith(
                      color: c.statusWarning,
                    ),
                  )
                : value == null
                ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 2,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: c.outlineVariant.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Text(
                'not labeled',
                style: AppTypography.bodySm.copyWith(color: c.onSurfaceTertiary),
              ),
            )
                : Text(
              value,
              style: AppTypography.bodyMd.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
