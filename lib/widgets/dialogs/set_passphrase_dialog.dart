import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../domain/logic/backup_crypto.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// The "Set a passphrase" dialog (issue #35).
///
/// Its own StatefulWidget, shown via [SmartDialog], rather than an inline
/// builder with controllers in the caller. A State's own `dispose()` runs
/// after the dialog finishes animating out — which is the correct moment.
/// The bug this replaces called `controller.dispose()` immediately after
/// the dialog popped, then the TextField rebuilt against it during the
/// exit animation and threw "A TextEditingController was used after being
/// disposed".
///
/// Returns the chosen passphrase, or null when the person cancelled or
/// tapped the mask.
Future<String?> showSetPassphraseDialog() async {
  return await SmartDialog.show<String>(
    clickMaskDismiss: true,
    builder: (_) => const _SetPassphraseDialog(),
  );
}

class _SetPassphraseDialog extends StatefulWidget {
  const _SetPassphraseDialog();

  @override
  State<_SetPassphraseDialog> createState() => _SetPassphraseDialogState();
}

class _SetPassphraseDialogState extends State<_SetPassphraseDialog> {
  final _controller = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _controller.text;
    final c = _confirm.text;
    final validation = BackupCrypto.validatePassphrase(p);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    if (p != c) {
      setState(() => _error = "The two don't match.");
      return;
    }
    SmartDialog.dismiss(result: p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Set a passphrase'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every scheduled backup is encrypted with this passphrase. '
                'Fuata cannot recover it for you — if you forget it, those '
                'backups cannot be opened.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Passphrase',
              // The eye toggles both fields at once, so a reveal is
              // unambiguous — a person checking a typo in a 20-character
              // passphrase can see what they meant to type.
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
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'Again'),
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
          onPressed: () => SmartDialog.dismiss(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}