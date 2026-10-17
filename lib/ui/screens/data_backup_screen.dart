import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/backup_crypto.dart';
import '../../domain/logic/backup_import.dart';
import '../../domain/logic/backup_service.dart';
import '../../platform/backup_files.dart';
import '../../platform/backup_passphrase_store.dart';
import '../../widgets/backup/import_preview_card.dart';
import '../../widgets/dialogs/enter_passphrase_dialog.dart';
import '../../widgets/personalization/section_card.dart';
import '../../widgets/personalization/toggle_row.dart';
import '../providers/app_providers.dart';
import '../providers/backup_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Back up & restore (issue #24, US-15, ui-design-brief.md 7.12 "Privacy &
/// data"). Two jobs, both by file and both on the person's terms:
///
///  - Save: everything Fuata knows, as one JSON file, wherever they pick.
///  - Restore: read a file, show exactly what it would do, and only then —
///    on their say-so — do it. Nothing is written while previewing, a file
///    with any problem changes nothing, and records that already exist but
///    differ are kept as they are unless the person chooses otherwise.
class DataBackupScreen extends ConsumerStatefulWidget {
  const DataBackupScreen({super.key});

  @override
  ConsumerState<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends ConsumerState<DataBackupScreen> {
  bool _busy = false;
  bool _includeRawText = false;

  ImportPreview? _preview;
  ConflictPolicy _policy = ConflictPolicy.keepMine;
  bool _restoreSettings = false;

  ({String text, bool isError})? _message;

  void _say(String text, {bool isError = false}) =>
      _message = (text: text, isError: isError);

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(backupServiceProvider);
      final built = await service.buildExport(includeRawText: _includeRawText);
      final saved = await ref
          .read(backupFilesProvider)
          .saveText(
            suggestedName: service.suggestedFileName(),
            content: built.json,
          );
      if (!mounted) return;
      setState(() {
        if (saved) {
          final s = built.snapshot;
          _say(
            'Saved: ${s.units.length} money unit${s.units.length == 1 ? '' : 's'}, '
            '${s.transactions.length} transaction${s.transactions.length == 1 ? '' : 's'}. '
            'Keep the file somewhere safe — it holds your money history.',
          );
        }
      });
    } on BackupFileException catch (e) {
      if (mounted) setState(() => _say(e.message, isError: true));
    } catch (_) {
      if (mounted) {
        setState(() => _say("Couldn't create the backup.", isError: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final picked = await ref.read(backupFilesProvider).pickText();
      if (picked == null) return;

      var plaintext = picked;
      if (BackupCrypto.looksEncrypted(picked)) {
        var decrypted = false;

        // Try the cached passphrase first — the person set it for scheduled
        // backups, so if this is one, it will already be cached.
        final cached = await BackupPassphraseStore.read();
        if (cached != null) {
          try {
            plaintext = await BackupCrypto.decode(picked, passphrase: cached);
            decrypted = true;
          } on Exception {
            // Wrong cached passphrase (file from a different Fuata setup).
            // Fall through to prompting.
          }
        }

        if (!decrypted) {
          if (!mounted) return;
          final entered = await showEnterPassphraseDialog();
          if (entered == null) return;
          try {
            plaintext = await BackupCrypto.decode(picked, passphrase: entered);
          } on Exception {
            if (mounted) {
              setState(() => _say(
                "That passphrase didn't open this file. Nothing was changed.",
                isError: true,
              ));
            }
            return;
          }
        }
      }

      final preview = await ref.read(backupServiceProvider).preview(plaintext);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _policy = ConflictPolicy.keepMine;
        _restoreSettings = preview.hasSettings && !preview.phoneHasData;
      });
    } on BackupFileException catch (e) {
      if (mounted) setState(() => _say(e.message, isError: true));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _say("Couldn't read that file. Nothing was changed.", isError: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    final plan = preview?.plan;
    if (preview == null || plan == null) return;

    // Replacing is the one destructive path: say so, once, plainly.
    if (_policy == ConflictPolicy.useFile && plan.hasConflicts) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace what’s on this phone?'),
          content: Text(
            '${plan.conflictCount} item${plan.conflictCount == 1 ? '' : 's'} '
            'on this phone will be replaced by the file’s version. '
            'This can’t be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final outcome = await ref
          .read(backupServiceProvider)
          .apply(preview, policy: _policy, restoreSettings: _restoreSettings);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _say(_outcomeText(outcome));
      });
    } catch (_) {
      // The write is one transaction, so a failure changed nothing.
      if (mounted) {
        setState(
          () =>
              _say('The import failed, so nothing was changed.', isError: true),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _outcomeText(ImportOutcome o) {
    final parts = <String>[
      if (o.added > 0) 'added ${o.added}',
      if (o.replaced > 0) 'replaced ${o.replaced}',
      if (o.skipped > 0) 'kept ${o.skipped} of yours as they were',
      if (o.settingsRestored) 'restored your settings',
    ];
    if (parts.isEmpty) return 'Done — there was nothing to change.';
    final joined = parts.join(', ');
    return 'Done: ${joined[0].toUpperCase()}${joined.substring(1)}.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unitCount = ref.watch(unitsProvider).value?.length ?? 0;
    final txCount = ref.watch(transactionsProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Back up & restore')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            if (_message != null) ...[
              _MessageBanner(message: _message!),
              const SizedBox(height: AppSpacing.lg),
            ],
            SectionCard(
              title: 'Save a backup',
              children: [
                Text(
                  'One file with your money units, transactions, limits, '
                  'message rules and settings ($unitCount unit'
                  '${unitCount == 1 ? '' : 's'}, $txCount transaction'
                  '${txCount == 1 ? '' : 's'} right now). You choose where it goes; '
                  'Fuata never sends it anywhere.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ToggleRow(
                  title: 'Include original message text',
                  subtitle: 'Off by default. Only matters for messages you chose to keep in full.',
                  value: _includeRawText,
                  onChanged: (v) => setState(() => _includeRawText = v),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Save backup file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Restore from a backup',
              children: [
                Text(
                  'Pick a Fuata backup file. You’ll see what it would do '
                  'first — nothing changes until you say so, and anything '
                  'already on this phone is kept unless you choose otherwise.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_preview == null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _choose,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Choose a backup file'),
                    ),
                  )
                else
                  ImportPreviewCard(
                    preview: _preview!,
                    policy: _policy,
                    restoreSettings: _restoreSettings,
                    busy: _busy,
                    onPolicy: (p) => setState(() => _policy = p),
                    onRestoreSettings: (v) =>
                        setState(() => _restoreSettings = v),
                    onImport: _import,
                    onCancel: () => setState(() => _preview = null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});
  final ({String text, bool isError}) message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final error = message.isError;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: error ? c.statusDangerContainer : c.statusSafeContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: error ? c.statusDanger : c.statusSafe,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message.text,
              style: AppTypography.bodySm.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
