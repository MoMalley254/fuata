import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/toggle_row.dart';

/// Quiet hours (ui-design-brief.md 7.8, issue #63). Inside the window an
/// alert still arrives — it just doesn't buzz or pop up. Dropping it would
/// mean a limit crossed at 2am is never mentioned at all.
class QuietHoursCard extends ConsumerWidget {
  const QuietHoursCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    Future<void> pick({required bool start}) async {
      final minute = start ? s.quietStartMinute : s.quietEndMinute;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      );
      if (picked == null) return;
      final value = picked.hour * 60 + picked.minute;
      await repo.updateSettings(
        start
            ? s.copyWith(quietStartMinute: value)
            : s.copyWith(quietEndMinute: value),
      );
    }

    String fmt(int minute) =>
        TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToggleRow(
          title: 'Quiet hours',
          subtitle: 'Alerts still arrive, just without sound or a pop-up.',
          value: s.quietHoursEnabled,
          onChanged: (on) => repo.updateSettings(s.copyWith(quietHoursEnabled: on)),
        ),
        if (s.quietHoursEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'From',
                  value: fmt(s.quietStartMinute),
                  onTap: () => pick(start: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TimeButton(
                  label: 'Until',
                  value: fmt(s.quietEndMinute),
                  onTap: () => pick(start: false),
                ),
              ),
            ],
          ),
          if (s.quietStartMinute == s.quietEndMinute) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Same start and end means no quiet hours.',
              style: AppTypography.labelSm.copyWith(color: c.onSurfaceTertiary),
            ),
          ],
        ],
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.labelSm.copyWith(color: c.onSurfaceVariant)),
              Text(value,
                  style: AppTypography.bodyLg.copyWith(color: c.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
