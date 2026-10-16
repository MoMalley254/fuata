// ---------------------------------------------------------------------------
// Scheduling the daily / weekly / monthly summary notifications (issue #31).
//
// Uses flutter_local_notifications' zonedSchedule with matchDateTimeComponents
// so Android re-fires the notification every period without Fuata needing to
// be running. The text is baked in at schedule time; the sync provider
// (summary_notification_providers.dart) reschedules whenever the data or the
// settings change, so the body is always "as of the last time Fuata noticed
// something moved".
//
// Three fixed ids, one per period, so a reschedule *replaces* the pending
// notification rather than stacking a second one beside it — same trick the
// banner uses for its own single id.
//
// The timing helpers (nextDaily / nextWeekly / nextMonthly) are top-level
// pure functions on purpose: they're the whole of "when does the next one
// fire?" and they take an explicit `now` so a test can pin the clock.
// Everything the class below does with them is one line of wiring into
// zonedSchedule.
//
// Nothing here logs amounts or the notification body.
// ---------------------------------------------------------------------------

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/settings.dart';
import 'banner.dart';

/// The three bodies the scheduler puts into the three notifications. Each
/// is computed once by the caller (which has the repositories) and handed
/// here; the scheduler never touches the database.
class SummaryNotificationTexts {
  final String daily;
  final String weekly;
  final String monthly;
  const SummaryNotificationTexts({
    required this.daily,
    required this.weekly,
    required this.monthly,
  });
}

// ---------------------------------------------------------------------------
// Timing helpers. Pure functions: no I/O, no clock reads (the caller passes
// `now`), no dependency on the plugin. Testable in test/domain/.
// ---------------------------------------------------------------------------

/// The next local occurrence of [minute] minutes past midnight, strictly
/// after [now].
///
/// Strictly-after is deliberate: when the settings change *at* the exact
/// minute the summary is due, rescheduling it for "now" would fire it a
/// second time the moment the write landed. Rolling to tomorrow instead
/// means a person who turns the daily summary on at exactly 20:00 gets
/// their first one tomorrow, not a duplicate of the one that just fired.
tz.TZDateTime nextDaily(tz.TZDateTime now, int minute) {
  final today = tz.TZDateTime(
    now.location, now.year, now.month, now.day,
    minute ~/ 60, minute % 60,
  );
  if (today.isAfter(now)) return today;
  // `day + 1` over a month end or a year end is normalised by the
  // constructor — 31 Oct + 1 day is 1 Nov, no special case needed here.
  return tz.TZDateTime(
    now.location, now.year, now.month, now.day + 1,
    minute ~/ 60, minute % 60,
  );
}

/// The next local occurrence of [weekday] (1 = Mon … 7 = Sun, matching
/// Dart's `DateTime.weekday`) at [minute], strictly after [now].
///
/// Any weekday occurs at least once in any 8 consecutive days (today plus
/// the seven after it), so the loop is guaranteed to return; the throw at
/// the end is defensive, not reachable.
tz.TZDateTime nextWeekly(tz.TZDateTime now, int weekday, int minute) {
  for (var i = 0; i < 8; i++) {
    final when = tz.TZDateTime(
      now.location, now.year, now.month, now.day + i,
      minute ~/ 60, minute % 60,
    );
    if (when.weekday == weekday && when.isAfter(now)) return when;
  }
  throw StateError('nextWeekly: no weekday $weekday in 8 days from $now');
}

/// The next local occurrence of day-of-month [day] at [minute], strictly
/// after [now].
///
/// [day] is bounded to 1..28 by the settings model, so every month has it
/// — a monthly summary can never silently skip February.
tz.TZDateTime nextMonthly(tz.TZDateTime now, int day, int minute) {
  final thisMonth = tz.TZDateTime(
    now.location, now.year, now.month, day,
    minute ~/ 60, minute % 60,
  );
  if (thisMonth.isAfter(now)) return thisMonth;
  // `month + 1` on December is 13, which the constructor normalises to
  // January of the next year — again, no special case.
  return tz.TZDateTime(
    now.location, now.year, now.month + 1, day,
    minute ~/ 60, minute % 60,
  );
}

class SummaryNotificationScheduler {
  SummaryNotificationScheduler._();
  static final instance = SummaryNotificationScheduler._();

  static const dailyId = 3001;
  static const weeklyId = 3002;
  static const monthlyId = 3003;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Loads the timezone database and pins the local zone to whatever the
  /// device reports. Idempotent; safe to call from every app start.
  ///
  /// If the device's zone can't be read (rare — the platform channel is
  /// missing on widget tests, or an OEM reports a name the tz database
  /// doesn't know), we fall back to UTC rather than throwing. That's a
  /// worse schedule but not a broken app; the next app start tries again.
  Future<void> init() async {
    if (_initialised) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      // flutter_timezone 4.x returns a TimezoneInfo, not a bare String.
      // .identifier is the IANA name ("Africa/Nairobi") that
      // tz.getLocation expects.
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Leave tz.local at its default (UTC). A future start will retry.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialised = true;
  }

  /// (Re)schedules each enabled period, cancels each disabled one. Called
  /// on every data or settings change, and on app resume — see
  /// summary_notification_providers.dart.
  Future<void> scheduleAll({
    required AppSettings settings,
    required SummaryNotificationTexts texts,
    required bool redactOnLockScreen,
  }) async {
    await init();

    if (!settings.summaryNotificationsEnabled) {
      await cancelAll();
      return;
    }

    // One "now" for all three: if the three helpers each read the clock
    // themselves, a slow first call could land the second in a different
    // minute — a real, if tiny, inconsistency. One snapshot avoids it.
    final now = tz.TZDateTime.now(tz.local);

    await _apply(
      id: dailyId,
      enabled: settings.summaryDailyEnabled,
      when: nextDaily(now, settings.summaryDailyMinute),
      title: '📊 Today',
      body: texts.daily,
      match: DateTimeComponents.time,
      redact: redactOnLockScreen,
    );
    await _apply(
      id: weeklyId,
      enabled: settings.summaryWeeklyEnabled,
      when: nextWeekly(
        now,
        settings.summaryWeeklyWeekday,
        settings.summaryWeeklyMinute,
      ),
      title: '📊 This week',
      body: texts.weekly,
      match: DateTimeComponents.dayOfWeekAndTime,
      redact: redactOnLockScreen,
    );
    await _apply(
      id: monthlyId,
      enabled: settings.summaryMonthlyEnabled,
      when: nextMonthly(
        now,
        settings.summaryMonthlyDay,
        settings.summaryMonthlyMinute,
      ),
      title: '📊 This month',
      body: texts.monthly,
      match: DateTimeComponents.dayOfMonthAndTime,
      redact: redactOnLockScreen,
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancel(id: dailyId);
    await _plugin.cancel(id: weeklyId);
    await _plugin.cancel(id: monthlyId);
  }

  Future<void> _apply({
    required int id,
    required bool enabled,
    required tz.TZDateTime when,
    required String title,
    required String body,
    required DateTimeComponents match,
    required bool redact,
  }) async {
    if (!enabled) {
      await _plugin.cancel(id: id);
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          BannerPlatform.summaryChannelId,
          BannerPlatform.summaryChannelName,
          channelDescription: BannerPlatform.summaryChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          autoCancel: true,
          visibility: redact
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      // Inexact: no SCHEDULE_EXACT_ALARM permission, no user prompt, and a
      // summary doesn't need to land on the exact second. The OS batches
      // it with other alarms while the phone is idle.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }
}