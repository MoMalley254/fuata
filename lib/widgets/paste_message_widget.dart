import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/logic/parser.dart';
import '../domain/logic/paste_parser.dart';
import '../domain/models/money.dart';
import '../domain/models/parsed_paste.dart';
import '../domain/models/template.dart';
import '../domain/models/transaction.dart';
import '../ui/providers/app_providers.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';
import 'capture_review/paste_message_card.dart';

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
    await _tryParse(text);
  }

  Future<void> _tryParse(String text) async {
    final units = ref.read(unitsProvider).value ?? [];
    // Straight from the repository, one read per unit. (The first version
    // awaited unitTemplatesProvider(id).future, which never completed
    // here, so the card showed neither details nor an error.)
    final templates = ref.read(templateRepositoryProvider);
    final byUnit = <String, List<CaptureTemplate>>{};
    for (final u in units) {
      byUnit[u.id] = await templates.watchTemplates(unitId: u.id).first;
    }
    if (!mounted) return;

    final result = PasteParser.parse(text, units: units, templatesByUnit: byUnit);
    final parsed = result.parsed;
    setState(() {
      _parsed = parsed;
      _error = result.failure?.message;
    });
    if (parsed != null) widget.onParsed?.call(parsed);
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
              PasteMessageCard(
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

