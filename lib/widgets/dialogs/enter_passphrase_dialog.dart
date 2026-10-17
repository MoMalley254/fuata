import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// The "This backup is encrypted" dialog (issue #35's restore path).
///
/// Sibling of [showSetPassphraseDialog] but simpler: it only *collects*
/// a passphrase, it cannot validate it (the caller hands it to
/// BackupCrypto.decode, which throws if wrong). Separate because the two
/// dialogs say genuinely different things — this one is "unlock this
/// specific file", not "choose a key for future files".
///
/// Same fix as [showSetPassphraseDialog]: its own StatefulWidget, driven
/// by [SmartDialog], so the TextEditingController is disposed at the
/// right moment.
///
/// Returns the entered passphrase, or null when the person cancelled.
Future<String?> showEnterPassphraseDialog() async {
  return await SmartDialog.show<String>(
    clickMaskDismiss: true,
    builder: (_) => const _EnterPassphraseDialog(),
  );
}

class _EnterPassphraseDialog extends StatefulWidget {
  const _EnterPassphraseDialog();

  @override
  State<_EnterPassphraseDialog> createState() => _EnterPassphraseDialogState();
}

class _EnterPassphraseDialogState extends State<_EnterPassphraseDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => SmartDialog.dismiss(result: _controller.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('This backup is encrypted'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the passphrase this backup was made with.',
            style: AppTypography.bodyMd.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => SmartDialog.dismiss(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Open')),
      ],
    );
  }
}