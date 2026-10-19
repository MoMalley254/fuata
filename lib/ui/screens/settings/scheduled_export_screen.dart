import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/logic/backup_crypto.dart';
import '../../../domain/logic/scheduled_export.dart';
import '../../../domain/models/settings.dart';
import '../../../platform/backup_passphrase_store.dart';
import '../../../platform/scheduled_export.dart';
import '../../../widgets/dialogs/set_passphrase_dialog.dart';
import '../../../widgets/personalization/action_row.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../../widgets/personalization/toggle_row.dart';
import '../../providers/app_providers.dart';
import '../../providers/scheduled_export_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Scheduled encrypted export (issue #35).
///
/// Two preconditions the toggle can't override: a chosen folder and a set
/// passphrase. Without both, an unattended run would fail every night with
/// nothing the person could see; gating here means the toggle is on only
/// when it will actually do something.
class ScheduledExportScreen extends ConsumerStatefulWidget {
  const ScheduledExportScreen({super.key});

  @override
  ConsumerState<ScheduledExportScreen> createState() =>
      _ScheduledExportScreenState();
}

class _ScheduledExportScreenState
    extends ConsumerState<ScheduledExportScreen> {
  bool _runningNow = false;
  String? _lastRunMessage;

  void _update(AppSettings Function(AppSettings) fn) {
    ref.read(settingsRepositoryProvider).updateSettings(fn(ref.read(currentSettingsProvider)));
  }

  Future<void> _pickFolder() async {
    final uri = await pickScheduledExportFolder();
    if (uri == null) return;
    final old = ref.read(currentSettingsProvider).scheduledExportFolderUri;
    if (old != null && old != uri) {
      await clearScheduledExportFolder(old);
    }
    _update((s) => s.copyWith(scheduledExportFolderUri: uri));
    // Force a re-read so the folder name shows up.
    setState(() {});
  }

  Future<void> _setPassphrase() async {
    final passphrase = await showSetPassphraseDialog();
    if (passphrase == null) return;
    await BackupPassphraseStore.write(passphrase);
    _update((s) => s.copyWith(scheduledExportPassphraseSet: true));
    if (mounted) setState(() {});
  }

  Future<void> _runNow() async {
    final s = ref.read(currentSettingsProvider);
    final folder = s.scheduledExportFolderUri;
    if (folder == null) return;
    final passphrase = await BackupPassphraseStore.read();
    if (passphrase == null) return;

    setState(() {
      _runningNow = true;
      _lastRunMessage = null;
    });
    try {
      final built = await ref
          .read(backupServiceProvider)
          .buildExport(includeRawText: s.scheduledExportIncludeRawText);
      final encrypted = await BackupCrypto.encode(built.json, passphrase: passphrase);
      final ok = await writeToExportFolder(
        folderUri: folder,
        filename: scheduledExportFileName(DateTime.now()),
        content: encrypted,
      );
      if (!mounted) return;
      setState(() {
        _lastRunMessage = ok
            ? 'Saved just now.'
            : "Couldn't write to that folder. Try picking it again.";
      });
      ref.invalidate(scheduledExportStatusProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _lastRunMessage = "Couldn't create the backup.");
      }
    } finally {
      if (mounted) setState(() => _runningNow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = ref.watch(currentSettingsProvider);
    final statusAsync = ref.watch(scheduledExportStatusProvider);
    final folderUri = s.scheduledExportFolderUri;
    final folderReady = folderUri != null && folderUri.isNotEmpty;
    final passphraseReady = s.scheduledExportPassphraseSet;
    final canEnable = folderReady && passphraseReady;

    // The switch reads "off" until the prerequisites are in place — a switch
    // that shows "on" while nothing is scheduled is a lie. The stored
    // preference is untouched; when the missing piece is set the switch
    // flips back to whatever the person last chose.
    final switchValue = canEnable && s.scheduledExportEnabled;

    // Subtitle names *exactly* what's missing. The setup card below has the
    // actions; this is the one-line answer for "why is that switch dead?".
    final subtitle = !canEnable
        ? (folderReady
        ? 'Set a passphrase first.'
        : passphraseReady
        ? 'Choose a folder first.'
        : 'Set a folder and a passphrase first.')
        : s.scheduledExportEnabled
        ? 'Fuata writes one file every '
        '${s.scheduledExportFrequency == ScheduledExportFrequency.daily ? 'day' : 'week'}.'
        : 'Off — turn it on to start.';

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled backups')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'An encrypted backup, written to a folder you choose, on a '
                  'schedule — so your money history survives losing the phone '
                  'without you having to remember to export.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),

            // F35b: when the toggle won't turn on, the first thing on screen
            // says why and gives each missing piece its own tap to fix.
            // Above the cards on purpose: a disabled control whose reason
            // lives three sections down is a dead end.
            if (!canEnable) ...[
              const SizedBox(height: AppSpacing.lg),
              _SetupNeededCard(
                folderReady: folderReady,
                passphraseReady: passphraseReady,
                onPickFolder: _pickFolder,
                onSetPassphrase: _setPassphrase,
              ),
            ],

            // Order: what it needs, where it goes, how it's encrypted, then
            // when it runs. Reading top to bottom, the prerequisites come
            // first and the switch is the last thing set up, not the first
            // thing blocked.
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Where',
              children: [
                FutureBuilder<String?>(
                  future: folderUri == null
                      ? Future.value(null)
                      : scheduledExportFolderName(folderUri),
                  builder: (context, snap) => ActionRow(
                    icon: Icons.folder_outlined,
                    title: snap.data ??
                        (folderUri == null ? 'Choose a folder' : 'Folder'),
                    subtitle: folderUri == null
                        ? 'Fuata writes each backup here'
                        : 'Tap to change',
                    onTap: _pickFolder,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Encryption',
              children: [
                ActionRow(
                  icon: Icons.key_outlined,
                  title: passphraseReady ? 'Passphrase set' : 'Set a passphrase',
                  subtitle: passphraseReady
                      ? 'Changing it only affects new backups; saved ones still need the old passphrase'
                      : 'Backups are encrypted with this; Fuata cannot recover it',
                  onTap: _setPassphrase,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Schedule',
              children: [
                ToggleRow(
                  title: 'Scheduled backups',
                  subtitle: subtitle,
                  value: switchValue,
                  onChanged: canEnable
                      ? (v) => _update((x) => x.copyWith(scheduledExportEnabled: v))
                      : null,
                ),
                if (s.scheduledExportEnabled && canEnable) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final f in ScheduledExportFrequency.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: s.scheduledExportFrequency == f,
                          onSelected: (_) => _update(
                                (x) => x.copyWith(scheduledExportFrequency: f),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TimeRow(
                    label: 'At',
                    minute: s.scheduledExportMinute,
                    onPick: (m) =>
                        _update((x) => x.copyWith(scheduledExportMinute: m)),
                  ),
                  if (s.scheduledExportFrequency ==
                      ScheduledExportFrequency.weekly) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _WeekdayRow(
                      value: s.scheduledExportWeekday,
                      onPick: (w) =>
                          _update((x) => x.copyWith(scheduledExportWeekday: w)),
                    ),
                  ],
                ],
              ],
            ),

            if (s.scheduledExportEnabled && canEnable) ...[
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Last backup',
                children: [
                  statusAsync.when(
                    loading: () => Text(
                      'Checking…',
                      style: AppTypography.bodyMd
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                    error: (_, _) => Text(
                      "Couldn't read the last run.",
                      style: AppTypography.bodyMd
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                    data: (status) {
                      if (status.lastRunAt == null) {
                        return Text(
                          "Hasn't run yet.",
                          style: AppTypography.bodyMd
                              .copyWith(color: c.onSurfaceVariant),
                        );
                      }
                      final when =
                      DateFormat('d MMM, h:mm a').format(status.lastRunAt!);
                      final ok = status.lastRunSuccess;
                      return Text(
                        ok
                            ? 'Last run: $when.'
                            : 'Last run: $when — failed (${status.lastRunError ?? 'unknown'}).',
                        style: AppTypography.bodyMd.copyWith(
                          color: ok ? c.onSurface : c.statusWarning,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _runningNow ? null : _runNow,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_runningNow ? 'Running…' : 'Run now'),
                    ),
                  ),
                  if (_lastRunMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _lastRunMessage!,
                      style: AppTypography.bodySm
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            ToggleRow(
              title: 'Include original message text',
              subtitle:
              'Off by default. Only matters for messages you chose to keep in full.',
              value: s.scheduledExportIncludeRawText,
              onChanged: (v) =>
                  _update((x) => x.copyWith(scheduledExportIncludeRawText: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.minute,
    required this.onPick,
  });
  final String label;
  final int minute;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
        ),
        TextButton(
          onPressed: () async {
            final picked =
            await showTimePicker(context: context, initialTime: t);
            if (picked != null) onPick(picked.hour * 60 + picked.minute);
          },
          child: Text(t.format(context)),
        ),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.value, required this.onPick});
  final int value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        Expanded(
          child: Text('On',
              style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
        ),
        DropdownButton<int>(
          value: value,
          onChanged: (v) => v != null ? onPick(v) : null,
          items: [
            for (var i = 1; i <= 7; i++)
              DropdownMenuItem(value: i, child: Text(names[i - 1])),
          ],
        ),
      ],
    );
  }
}

/// A prominent answer to "why is the toggle dead?", placed above the
/// cards so the person sees it without having to hunt for it. Every
/// missing piece is a line with its own tap: the point is that turning
/// the feature on is one obvious gesture away, not "go read the docs".
class _SetupNeededCard extends StatelessWidget {
  const _SetupNeededCard({
    required this.folderReady,
    required this.passphraseReady,
    required this.onPickFolder,
    required this.onSetPassphrase,
  });

  final bool folderReady;
  final bool passphraseReady;
  final VoidCallback onPickFolder;
  final VoidCallback onSetPassphrase;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.statusWarningContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.statusWarningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: c.statusWarning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "Before you can turn this on, you'll need:",
                  style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SetupItem(
            done: folderReady,
            label: 'A folder to save to',
            onTap: folderReady ? null : onPickFolder,
          ),
          const SizedBox(height: AppSpacing.xs),
          _SetupItem(
            done: passphraseReady,
            label: 'A passphrase to encrypt with',
            onTap: passphraseReady ? null : onSetPassphrase,
          ),
        ],
      ),
    );
  }
}

class _SetupItem extends StatelessWidget {
  const _SetupItem({
    required this.done,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done ? c.statusSafe : c.statusWarning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMd.copyWith(
                    color: done ? c.onSurfaceVariant : c.onSurface,
                    // Struck through once set, so the two states read at a
                    // glance without relying on the icon colour alone.
                    decoration:
                    done ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
              ),
              if (!done) ...[
                Text(
                  'Set up',
                  style: AppTypography.labelMd.copyWith(color: c.primary),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: c.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}