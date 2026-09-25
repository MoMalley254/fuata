
import 'package:flutter/material.dart';
import 'package:fuata/widgets/personalization/section_card.dart';
import 'package:fuata/widgets/personalization/toggle_row.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../coming_soon_row.dart';

class PrivacyCard extends StatelessWidget {
  final AppSettings settings;
  final void Function(AppSettings Function(AppSettings)) onChanged;
  const PrivacyCard({super.key, required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SectionCard(
      title: 'Privacy & data',
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
          onChanged: (v) => onChanged((s) => s.copyWith(amountsHiddenInRecents: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ToggleRow(
          title: 'Redact banner on lock screen',
          subtitle: 'Hides amounts in the notification banner until the phone is unlocked.',
          value: settings.redactedLockScreenBanner,
          onChanged: (v) => onChanged((s) => s.copyWith(redactedLockScreenBanner: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        const ComingSoonRow(
          icon: Icons.import_export_rounded,
          title: 'Export / Import',
          subtitle: 'Back up or move your data as a JSON file — coming in #24',
        ),
        const SizedBox(height: AppSpacing.sm),
        ComingSoonRow(
          icon: Icons.delete_outline_rounded,
          title: 'Erase everything',
          subtitle: 'Wipe all data from this phone — coming once export (#24) can back it up first',
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
          "Erasing everything isn't wired up yet, so there's no way to get your data back first. "
              "It'll land once export/import (#24) does.",
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