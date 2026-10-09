import 'package:flutter/material.dart';
import 'package:fuata/widgets/personalization/section_card.dart';
import 'package:fuata/widgets/personalization/toggle_row.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'action_row.dart';

class PrivacyCard extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings Function(AppSettings)) onChanged;

  /// Opens Back up & restore (#24). A callback rather than a route so this
  /// widget stays free of screen imports, like the rest of lib/widgets.
  final VoidCallback onOpenBackup;

  /// Starts the two-step erase (issue #85). Also a callback: the confirm
  /// dialogs and the erase call itself belong to the screen that knows
  /// what to do afterwards.
  final VoidCallback onErase;
  const PrivacyCard({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onOpenBackup,
    required this.onErase,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SectionCard(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.statusSafeContainer,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: c.statusSafe),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Everything stays on this phone. No account, no server, no internet permission in the release build.',
                  style: AppTypography.bodySm.copyWith(color: c.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ToggleRow(
          title: 'Hide amounts in the app',
          subtitle:
          'Replaces every amount with dots until you turn this off. The eye '
              'on Today, My money and a unit page does the same thing.',
          value: settings.amountsHidden,
          onChanged: (v) => onChanged((s) => s.copyWith(amountsHidden: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ToggleRow(
          title: 'Hide in app switcher',
          subtitle:
          'Blanks Fuata in the app switcher. Also blocks screenshots and '
              'screen recording.',
          value: settings.amountsHiddenInRecents,
          onChanged: (v) =>
              onChanged((s) => s.copyWith(amountsHiddenInRecents: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ToggleRow(
          title: 'Hide banner on lock screen',
          subtitle:
          'Hides amounts in the notification banner until the phone is unlocked.',
          value: settings.redactedLockScreenBanner,
          onChanged: (v) =>
              onChanged((s) => s.copyWith(redactedLockScreenBanner: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        ActionRow(
          icon: Icons.import_export_rounded,
          title: 'Back up & restore',
          subtitle: 'Save your data as a file, or bring it back from one',
          onTap: onOpenBackup,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Deliberately an ActionRow (something real happens) rather than a
        // ComingSoonRow, now that #85 has wired it up. It keeps the same
        // bordered-card shape and the trailing chevron as the row above it,
        // so the two read as one group; the warning lives in the dialog,
        // which is where a person should meet it.
        ActionRow(
          icon: Icons.delete_outline_rounded,
          title: 'Erase everything',
          subtitle: 'Wipe all data from this phone. Save a backup first.',
          onTap: onErase,
        ),
      ],
    );
  }
}
