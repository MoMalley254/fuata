import 'package:flutter/material.dart';
import 'package:fuata/widgets/personalization/section_card.dart';
import 'package:fuata/widgets/personalization/toggle_row.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../coming_soon_row.dart';
import 'action_row.dart';

class PrivacyCard extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings Function(AppSettings)) onChanged;

  /// Opens Back up & restore (#24). A callback rather than a route so this
  /// widget stays free of screen imports, like the rest of lib/widgets.
  final VoidCallback onOpenBackup;
  const PrivacyCard({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onOpenBackup,
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
          title: 'Hide amounts in Recents',
          subtitle: 'Blurs amounts when the app switcher shows Fuata. Turns on the OS-level hook in a later issue.',
          value: settings.amountsHiddenInRecents,
          onChanged: (v) =>
              onChanged((s) => s.copyWith(amountsHiddenInRecents: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ToggleRow(
          title: 'Redact banner on lock screen',
          subtitle: 'Hides amounts in the notification banner until the phone is unlocked.',
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
        ComingSoonRow(
          icon: Icons.delete_outline_rounded,
          title: 'Erase everything',
          subtitle: 'Wipe all data from this phone — coming soon. Save a backup first.',
          onTap: () => _confirmEraseUnavailable(context),
        ),
      ],
    );
  }

  void _confirmEraseUnavailable(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Not yet'),
        content: const Text(
          "Erasing everything isn't wired up yet. When it is, it will ask you to "
          "save a backup first (Back up & restore) — you can do that any time.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
