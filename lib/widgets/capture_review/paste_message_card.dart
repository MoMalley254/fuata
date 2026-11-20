

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/parsed_paste.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class PasteMessageCard extends StatelessWidget {
  final String text;
  final ParsedPaste? parsed;
  final String? error;
  const PasteMessageCard({super.key,
    required this.text,
    required this.parsed,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: text.isEmpty && error == null
            ? BoxDecoration()
            : BoxDecoration(
          color: error != null
              ? c.statusDangerContainer
              : c.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          border: Border.all(
            color: error != null
                ? c.statusDangerBorder
                : c.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty) ...[
              Text(
                text,
                style: AppTypography.bodySm.copyWith(color: c.onSurface),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                error!,
                style: AppTypography.bodySm.copyWith(color: c.statusDanger),
              ),
            ],
            if (parsed != null) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(color: c.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Extracted details',
                style: AppTypography.labelSm.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _DetailRow(
                label: 'Amount',
                value:
                Money(parsed!.amountMinor, parsed!.currencyCode).format(),
              ),
              if (parsed!.counterparty != null)
                _DetailRow(label: 'To/From', value: parsed!.counterparty!),
              if (parsed!.occurredAt != null)
                _DetailRow(
                  label: 'When',
                  value: DateFormat('d MMM, h:mm a')
                      .format(parsed!.occurredAt!),
                ),
              if (parsed!.code != null)
                _DetailRow(label: 'Code', value: parsed!.code!),
              if (parsed!.feeMinor != null && parsed!.feeMinor! > 0)
                _DetailRow(
                  label: 'Fee',
                  value: Money(
                    parsed!.feeMinor!,
                    parsed!.currencyCode,
                  ).format(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}