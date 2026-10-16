import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/settings.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../../widgets/personalization/toggle_row.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Scheduled summary notifications (issue #31): a daily, weekly and
/// monthly reminder of how the money went. Each is optional and each has
/// its own time; the master switch turns the feature off without losing
/// the times the person already picked.
class SummaryNotificationsScreen extends ConsumerWidget {
  const SummaryNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) => repo.updateSettings(fn(s));

    return Scaffold(
      appBar: AppBar(title: const Text('Summary notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              children: [
                Text(
                  'A short nudge with how your money went — nothing you have '
                      'to open the app for. Everything is computed on this '
                      'phone, so the numbers are only as fresh as the last time '
                      'Fuata noticed something move.',
                  style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                ToggleRow(
                  title: 'Summary notifications',
                  subtitle: s.summaryNotificationsEnabled
                      ? 'On — choose which summaries below.'
                      : 'Off — nothing is scheduled.',
                  value: s.summaryNotificationsEnabled,
                  onChanged: (v) => update((x) => x.copyWith(summaryNotificationsEnabled: v)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Daily',
              children: [
                ToggleRow(
                  title: 'Every day',
                  subtitle: 'How today went, at a time you pick.',
                  value: s.summaryDailyEnabled,
                  onChanged: !s.summaryNotificationsEnabled
                      ? null
                      : (v) => update((x) => x.copyWith(summaryDailyEnabled: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TimeRow(
                  label: 'At',
                  minute: s.summaryDailyMinute,
                  enabled: s.summaryNotificationsEnabled && s.summaryDailyEnabled,
                  onPick: (m) => update((x) => x.copyWith(summaryDailyMinute: m)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Weekly',
              children: [
                ToggleRow(
                  title: 'Every week',
                  subtitle: 'How the week went so far.',
                  value: s.summaryWeeklyEnabled,
                  onChanged: !s.summaryNotificationsEnabled
                      ? null
                      : (v) => update((x) => x.copyWith(summaryWeeklyEnabled: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                _WeekdayRow(
                  value: s.summaryWeeklyWeekday,
                  enabled: s.summaryNotificationsEnabled && s.summaryWeeklyEnabled,
                  onPick: (d) => update((x) => x.copyWith(summaryWeeklyWeekday: d)),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TimeRow(
                  label: 'At',
                  minute: s.summaryWeeklyMinute,
                  enabled: s.summaryNotificationsEnabled && s.summaryWeeklyEnabled,
                  onPick: (m) => update((x) => x.copyWith(summaryWeeklyMinute: m)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Monthly',
              children: [
                ToggleRow(
                  title: 'Every month',
                  subtitle: 'How the month went so far.',
                  value: s.summaryMonthlyEnabled,
                  onChanged: !s.summaryNotificationsEnabled
                      ? null
                      : (v) => update((x) => x.copyWith(summaryMonthlyEnabled: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DayOfMonthRow(
                  value: s.summaryMonthlyDay,
                  enabled: s.summaryNotificationsEnabled && s.summaryMonthlyEnabled,
                  onPick: (d) => update((x) => x.copyWith(summaryMonthlyDay: d)),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TimeRow(
                  label: 'At',
                  minute: s.summaryMonthlyMinute,
                  enabled: s.summaryNotificationsEnabled && s.summaryMonthlyEnabled,
                  onPick: (m) => update((x) => x.copyWith(summaryMonthlyMinute: m)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Timing is approximate — Android may delay a summary by a few '
                  'minutes to save battery. Amounts in these notifications follow '
                  'the same lock-screen setting as the banner.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceTertiary),
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
    required this.enabled,
    required this.onPick,
  });
  final String label;
  final int minute;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
        ),
        TextButton(
          onPressed: enabled
              ? () async {
            final picked = await showTimePicker(context: context, initialTime: t);
            if (picked != null) onPick(picked.hour * 60 + picked.minute);
          }
              : null,
          child: Text(t.format(context)),
        ),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.value, required this.enabled, required this.onPick});
  final int value;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // 1 = Mon … 7 = Sun, matching Dart's DateTime.weekday.
    final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        Expanded(
          child: Text('On', style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
        ),
        DropdownButton<int>(
          value: value,
          onChanged: enabled ? (v) => v != null ? onPick(v) : null : null,
          items: [
            for (var i = 1; i <= 7; i++)
              DropdownMenuItem(value: i, child: Text(names[i - 1])),
          ],
        ),
      ],
    );
  }
}

class _DayOfMonthRow extends StatelessWidget {
  const _DayOfMonthRow({required this.value, required this.enabled, required this.onPick});
  final int value;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final suffix = switch (value) {
      1 || 21 => 'st',
      2 || 22 => 'nd',
      3 || 23 => 'rd',
      _ => 'th',
    };
    return Row(
      children: [
        Expanded(
          child: Text('On the', style: AppTypography.bodyMd.copyWith(color: c.onSurface)),
        ),
        DropdownButton<int>(
          value: value,
          onChanged: enabled ? (v) => v != null ? onPick(v) : null : null,
          // 1..28: every month has one, so no month is ever skipped.
          items: [
            for (var i = 1; i <= 28; i++)
              DropdownMenuItem(value: i, child: Text('$i$suffix')),
          ],
        ),
      ],
    );
  }
}