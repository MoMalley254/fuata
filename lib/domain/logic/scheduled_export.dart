// ---------------------------------------------------------------------------
// Pure logic for scheduled export (issue #35): when the next one is due,
// and what the file will be called. Both are the sort of thing that looks
// obvious and is wrong at a month end, a year end or a DST shift — so they
// are top-level functions with an explicit `now`, testable without a device
// or a clock.
//
// The actual alarm lives in ScheduledExportEngine.kt; this file's job is
// to compute the first trigger, and the interval the OS then repeats.
// DST handling: the first trigger is wall-clock-correct; repeated
// occurrences through `setInexactRepeating` drift by up to an hour twice a
// year, which for a daily backup is acceptable (and preferable to relying
// on SCHEDULE_EXACT_ALARM, which the person can revoke).
// ---------------------------------------------------------------------------

import '../models/settings.dart';

DateTime nextScheduledExportTrigger({
  required ScheduledExportFrequency frequency,
  required int minuteOfDay,
  required int weekday, // 1 = Mon … 7 = Sun; ignored when daily
  required DateTime now,
}) {
  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  final today = DateTime(now.year, now.month, now.day);
  final todayAtTime =
  DateTime(today.year, today.month, today.day, hour, minute);

  if (frequency == ScheduledExportFrequency.daily) {
    if (todayAtTime.isAfter(now)) return todayAtTime;
    return DateTime(today.year, today.month, today.day + 1, hour, minute);
  }

  // Weekly. `%7` in Dart returns 0..6 even for negatives.
  final daysUntil = (weekday - now.weekday) % 7;
  var candidate =
  DateTime(today.year, today.month, today.day + daysUntil, hour, minute);
  if (!candidate.isAfter(now)) {
    candidate =
        DateTime(candidate.year, candidate.month, candidate.day + 7, hour, minute);
  }
  return candidate;
}

/// Interval between repeats, in milliseconds.
int scheduledExportIntervalMs(ScheduledExportFrequency frequency) =>
    frequency == ScheduledExportFrequency.weekly
        ? const Duration(days: 7).inMilliseconds
        : const Duration(days: 1).inMilliseconds;

/// The file written by one export: `fuata-backup-20261017-201533.json.enc`.
/// Timestamped rather than overwriting, so a run that fails halfway can't
/// destroy an earlier good file; the person can prune history in their
/// file manager.
String scheduledExportFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'fuata-backup-${now.year}${two(now.month)}${two(now.day)}'
      '-${two(now.hour)}${two(now.minute)}${two(now.second)}.json.enc';
}