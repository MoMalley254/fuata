import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/logic/parser.dart';
import '../domain/models/money.dart';
import '../domain/models/parsed_paste.dart';
import '../domain/models/transaction.dart';
import '../ui/providers/app_providers.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

class PasteMessageWidget extends ConsumerStatefulWidget {
  const PasteMessageWidget({super.key, this.onParsed});
  final ValueChanged<ParsedPaste>? onParsed;

  @override
  ConsumerState<PasteMessageWidget> createState() => _PasteMessageWidgetState();
}

class _PasteMessageWidgetState extends ConsumerState<PasteMessageWidget> {
  final TextEditingController _messageController = TextEditingController();
  ParsedPaste? _parsed;
  String? _error;

  /// The paste half of US-09's "no permissions" paths — same CaptureService
  /// as the share target.
  Future<void> _paste(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nothing to paste.')));
      }
      return;
    }

    setState(() {
      _messageController.text = text;
      _error = null;
      _parsed = null;
    });
    _tryParse(text);
  }

  void _tryParse(String text) {
    final units = ref.read(unitsProvider).value ?? [];

    if (units.isEmpty) {
      setState(
        () => _error = 'Create money units first, then paste a message.',
      );
      return;
    }

    for (final unit in units) {
      final templates = ref.watch(unitTemplatesProvider(unit.id)).value ?? [];
      if (templates.isEmpty) continue;

      final result = Parser.parse(
        text,
        templates,
        currencyCode: unit.currencyCode,
      );

      if (result.matched &&
          result.fields != null &&
          result.fields!.amountMinor != null) {
        final parsed = ParsedPaste(
          rawText: text,
          amountMinor: result.fields!.amountMinor!,
          type: result.type ?? TxType.spent,
          counterparty: result.fields!.counterparty,
          occurredAt: result.fields!.occurredAt,
          code: result.fields!.code,
          feeMinor: result.fields!.feeMinor,
          balanceAfterMinor: result.fields!.balanceAfterMinor,
          unitId: unit.id,
          currencyCode: unit.currencyCode,
        );

        setState(() {
          _parsed = parsed;
          _error = null;
        });

        widget.onParsed?.call(parsed);
        return;
      }
    }

    setState(() {
      _parsed = null;
      _error =
          "Couldn't read this message. Try teaching Fuata this format first.";
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            FilledButton.icon(
              onPressed: () {
                // context.push(Routes.inboxPath);
                _paste(context);
              },
              icon: Icon(Icons.content_paste_go_outlined),
              label: Text('Paste Message'),
            ),
            if (_messageController.value.text.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _MessageCard(
                text: _messageController.text,
                parsed: _parsed,
                error: _error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String text;
  final ParsedPaste? parsed;
  final String? error;
  const _MessageCard({
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
