import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

/// The shared "before we jump to Android's settings" dialog (F17/F18).
///
/// Android's notification-access screen is one of the most alarming in the
/// OS: it warns that the app will be able to read *all* notifications,
/// including personal information such as contact names and message text,
/// and dismiss them. Android shows that message for every app with the
/// permission, on purpose. This dialog goes first: it says what Android
/// will say, what Fuata actually does, what to do if the switch is greyed
/// out, and what happens if they'd rather not.
///
/// One component, used from both the onboarding hand-off and Settings >
/// Auto-catch, so the two can never drift apart.
///
/// Returns true when the person tapped the primary action ("Take me
/// there" / "Got it"); false or null otherwise.
Future<bool?> showPermissionPrimerDialog({
  required BuildContext context,
  required String title,
  required String body,
  required List<String> bullets,
  String? androidWarning,
  String? restrictedSettingsNote,
  String? ifYoudRatherNot,
  String primaryLabel = 'Take me there',
  String secondaryLabel = 'Not now',
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => PermissionPrimerDialog(
      title: title,
      body: body,
      bullets: bullets,
      androidWarning: androidWarning,
      restrictedSettingsNote: restrictedSettingsNote,
      ifYoudRatherNot: ifYoudRatherNot,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
    ),
  );
}

class PermissionPrimerDialog extends StatelessWidget {
  const PermissionPrimerDialog({
    super.key,
    required this.title,
    required this.body,
    required this.bullets,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.androidWarning,
    this.restrictedSettingsNote,
    this.ifYoudRatherNot,
  });

  final String title;
  final String body;
  final List<String> bullets;
  final String? androidWarning;
  final String? restrictedSettingsNote;
  final String? ifYoudRatherNot;
  final String primaryLabel;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              style: AppTypography.bodyMd.copyWith(color: c.onSurface),
            ),
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final bullet in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bullet,
                          style: AppTypography.bodySm.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (androidWarning != null) ...[
              const SizedBox(height: AppSpacing.md),
              _Note(
                icon: Icons.info_outline_rounded,
                tone: _NoteTone.warning,
                text: androidWarning!,
              ),
            ],
            if (restrictedSettingsNote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _Note(
                icon: Icons.build_outlined,
                tone: _NoteTone.neutral,
                text: restrictedSettingsNote!,
              ),
            ],
            if (ifYoudRatherNot != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                ifYoudRatherNot!,
                style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
      actionsOverflowButtonSpacing: AppSpacing.sm,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(secondaryLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}

enum _NoteTone { neutral, warning }

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.tone});
  final IconData icon;
  final String text;
  final _NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      _NoteTone.warning => (c.statusWarningContainer, c.statusWarning),
      _NoteTone.neutral => (c.surfaceContainerHigh, c.onSurfaceVariant),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
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
