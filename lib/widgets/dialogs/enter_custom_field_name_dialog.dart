import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class CustomFieldNameDialog extends StatefulWidget {
  const CustomFieldNameDialog({super.key, required this.existing});
  final Set<String> existing;

  @override
  State<CustomFieldNameDialog> createState() => _CustomFieldNameDialogState();
}

class _CustomFieldNameDialogState extends State<CustomFieldNameDialog> {
  final _controller = TextEditingController();
  String? _error;

  static const _reserved = <String>{
    'amount',
    'code',
    'when',
    'payee',
    'balance',
    'fee',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    if (name.length > 30) {
      setState(() => _error = 'Keep it under 30 characters');
      return;
    }
    final lower = name.toLowerCase();
    if (_reserved.contains(lower)) {
      setState(() => _error = '"$name" is already a built-in field');
      return;
    }
    if (widget.existing.any((e) => e.toLowerCase() == lower)) {
      setState(() => _error = 'You already have a field called "$name"');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Name your field'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is this part of the message? e.g. "Till", "Account", '
            '"Cashier".',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'Field name'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTypography.bodySm.copyWith(color: c.statusDanger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
