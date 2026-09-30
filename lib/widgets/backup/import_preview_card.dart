import 'package:flutter/material.dart';

import '../../domain/logic/backup_import.dart';
import '../../domain/logic/backup_service.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import '../personalization/label.dart';
import '../personalization/toggle_row.dart';

/// What opening a backup file found, and the choices around importing it
/// (issue #24, ui-design-brief.md 7.12 "Privacy & data").
///
/// Shown only after the file has been read and compared with the phone;
/// nothing has been written yet. The two things that could surprise the
/// person are laid out before the button: which records already exist but
/// differ (and that "keep mine" is the default), and whether their
/// settings would be replaced.
class ImportPreviewCard extends StatelessWidget {
  const ImportPreviewCard({
    super.key,
    required this.preview,
    required this.policy,
    required this.restoreSettings,
    required this.busy,
    required this.onPolicy,
    required this.onRestoreSettings,
    required this.onImport,
    required this.onCancel,
  });

  final ImportPreview preview;
  final ConflictPolicy policy;
  final bool restoreSettings;
  final bool busy;
  final ValueChanged<ConflictPolicy> onPolicy;
  final ValueChanged<bool> onRestoreSettings;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return preview.canImport
        ? _ReadyBody(this)
        : _RefusedBody(preview: preview, onCancel: onCancel);
  }
}

String? _count(int n, String one, String many) =>
    n == 0 ? null : '$n ${n == 1 ? one : many}';

String _list(List<String?> parts) => parts.whereType<String>().join(', ');

/// Names of records that exist on both sides but differ, for the
/// "different from what's on this phone" list. Transactions are counted,
/// not listed — there can be hundreds.
List<String> _conflictNames(ImportPlan p) => [
  for (final c in p.units.conflicts) '“${c.incoming.name}” (money unit)',
  for (final c in p.limits.conflicts) 'Your ${c.incoming.period.name} limit',
  for (final c in p.templates.conflicts) '“${c.incoming.name}” (message rule)',
  for (final c in p.captureSources.conflicts)
    '“${c.incoming.displayName}” (watched app)',
  for (final c in p.categories.conflicts) '“${c.incoming.name}” (category)',
];

class _RefusedBody extends StatelessWidget {
  const _RefusedBody({required this.preview, required this.onCancel});
  final ImportPreview preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final blockers = preview.blockers;
    final hidden =
        (blockers.length > 6 ? blockers.length - 6 : 0) + preview.moreBlockers;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.statusDangerContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.statusDangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: c.statusDanger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "This file can't be imported",
                  style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nothing on your phone was changed.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final b in blockers.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '• $b',
                style: AppTypography.bodySm.copyWith(color: c.onSurface),
              ),
            ),
          if (hidden > 0)
            Text(
              'and $hidden more.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onCancel, child: const Text('Close')),
          ),
        ],
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody(this.card);
  final ImportPreviewCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plan = card.preview.plan!;
    final decoded = card.preview.decoded;

    final added = _list([
      _count(plan.units.added.length, 'money unit', 'money units'),
      _count(plan.transactions.added.length, 'transaction', 'transactions'),
      _count(plan.templates.added.length, 'message rule', 'message rules'),
      _count(plan.limits.added.length, 'limit', 'limits'),
      _count(plan.captureSources.added.length, 'watched app', 'watched apps'),
      _count(plan.categories.added.length, 'category', 'categories'),
    ]);

    final names = _conflictNames(plan);
    final txConflicts = plan.transactions.conflicts.length;
    final shownNames = names.take(5).toList();
    final hiddenNames = names.length - shownNames.length;

    final exportedAt = decoded.exportedAt?.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exportedAt == null
                ? 'Backup file'
                : 'Backup from ${_date(exportedAt)}',
            style: AppTypography.bodyMd.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Line(
            icon: Icons.add_circle_outline_rounded,
            color: c.statusSafe,
            text: added.isEmpty
                ? 'Nothing new to add'
                : 'New to this phone: $added',
          ),
          if (plan.identicalCount > 0)
            _Line(
              icon: Icons.check_circle_outline_rounded,
              color: c.onSurfaceVariant,
              text:
                  '${plan.identicalCount} already here and the same — skipped',
            ),
          if (plan.hasConflicts)
            _Line(
              icon: Icons.difference_outlined,
              color: c.statusWarning,
              text:
                  '${plan.conflictCount} already here but different from the file',
            ),
          if (plan.hasConflicts) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final n in shownNames)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 2),
                child: Text(
                  n,
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
            if (txConflicts > 0)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 2),
                child: Text(
                  '$txConflicts transaction${txConflicts == 1 ? '' : 's'}',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
            if (hiddenNames > 0)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 2),
                child: Text(
                  'and $hiddenNames more',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Label('For those, what should win?'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppChoiceChip(
                  label: 'Keep what’s on my phone',
                  selected: card.policy == ConflictPolicy.keepMine,
                  onTap: () => card.onPolicy(ConflictPolicy.keepMine),
                ),
                AppChoiceChip(
                  label: 'Use the file’s version',
                  selected: card.policy == ConflictPolicy.useFile,
                  onTap: () => card.onPolicy(ConflictPolicy.useFile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              card.policy == ConflictPolicy.keepMine
                  ? 'Your phone’s versions stay exactly as they are.'
                  : 'The file’s versions replace yours. This can’t be undone.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          if (card.preview.hasSettings) ...[
            const SizedBox(height: AppSpacing.md),
            ToggleRow(
              title: 'Also restore my settings',
              subtitle: card.preview.phoneHasData
                  ? 'Replaces your name, colours, banner and alert choices with the file’s.'
                  : 'Name, colours, banner and alert choices from the file.',
              value: card.restoreSettings,
              onChanged: card.onRestoreSettings,
            ),
          ],
          if (decoded.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${decoded.warnings.length} small thing${decoded.warnings.length == 1 ? ' was' : 's were'} tidied while reading the file.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: card.busy ? null : card.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed:
                    card.busy || (plan.changesNothing && !card.restoreSettings)
                    ? null
                    : card.onImport,
                child: Text(card.busy ? 'Importing…' : 'Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
