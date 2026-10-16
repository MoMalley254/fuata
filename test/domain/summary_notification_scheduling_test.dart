// Issue #31: the timing helpers that decide when the next daily / weekly /
// monthly summary notification is due.
//
// These are pure functions (top-level in summary_notifications.dart) that
// take an explicit `now` and the person's chosen time, and return the next
// wall-clock occurrence. They're the whole of "when does the next one
// fire?" — the scheduler class just wires them into zonedSchedule with the
// right matchDateTimeComponents. Testing them here means the timing logic
// is covered without a device, a plugin channel, or a running engine.
//
// Times are built in Africa/Nairobi (UTC+3, no DST) so the arithmetic is
// easy to reason about. The one DST-specific case at the bottom uses
// London, which does shift, to make sure the helpers respect wall-clock
// rather than an absolute 24-hour day.

import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/platform/summary_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location nairobi;

  setUpAll(() {
    // One-time load of the IANA database. Cheap enough to do here rather
    // than in each test.
    tzdata.initializeTimeZones();
    nairobi = tz.getLocation('Africa/Nairobi');
  });

  /// Shorthand for a wall-clock time in Nairobi.
  tz.TZDateTime at(int y, int mo, int d, int h, [int m = 0, int s = 0]) =>
      tz.TZDateTime(nairobi, y, mo, d, h, m, s);

  // ---------------------------------------------------------------------
  // Daily
  // ---------------------------------------------------------------------
  group('nextDaily', () {
    test('before the time today -> today', () {
      final now = at(2026, 10, 14, 10, 0);
      expect(nextDaily(now, 20 * 60), at(2026, 10, 14, 20, 0));
    });

    test('after the time today -> tomorrow', () {
      final now = at(2026, 10, 14, 21, 0);
      expect(nextDaily(now, 20 * 60), at(2026, 10, 15, 20, 0));
    });

    test('exactly at the time -> tomorrow, not today', () {
      // The strict "isAfter" matters here: on every settings change the
      // scheduler reschedules, and if "exactly at 20:00" returned "today
      // at 20:00" the person's 20:00 summary would fire a second time
      // the instant they toggled any option.
      final now = at(2026, 10, 14, 20, 0);
      expect(nextDaily(now, 20 * 60), at(2026, 10, 15, 20, 0));
    });

    test('one second after the time -> tomorrow', () {
      final now = at(2026, 10, 14, 20, 0, 1);
      expect(nextDaily(now, 20 * 60), at(2026, 10, 15, 20, 0));
    });

    test('one second before the time -> today', () {
      final now = at(2026, 10, 14, 19, 59, 59);
      expect(nextDaily(now, 20 * 60), at(2026, 10, 14, 20, 0));
    });

    test('crossing a month boundary', () {
      // 31 Oct 23:00 asking for 20:00 -> 1 Nov 20:00. The "day + 1"
      // in the helper must roll the month, not produce 32 Oct.
      final now = at(2026, 10, 31, 23, 0);
      expect(nextDaily(now, 20 * 60), at(2026, 11, 1, 20, 0));
    });

    test('crossing a year boundary', () {
      final now = at(2026, 12, 31, 23, 0);
      expect(nextDaily(now, 20 * 60), at(2027, 1, 1, 20, 0));
    });

    test('midnight (minute 0) is a valid time', () {
      final now = at(2026, 10, 14, 10, 0);
      // 00:00 today has already passed, so this rolls to tomorrow 00:00.
      expect(nextDaily(now, 0), at(2026, 10, 15, 0, 0));
    });

    test('23:59 (the last minute of the day) is a valid time', () {
      final now = at(2026, 10, 14, 10, 0);
      expect(nextDaily(now, 23 * 60 + 59), at(2026, 10, 14, 23, 59));
    });

    test('the returned time keeps the location of `now`', () {
      // The whole reason the helper takes `now` explicitly rather than
      // reading tz.local itself: whichever zone the caller builds `now`
      // in, that is the zone the answer is in.
      final tokyo = tz.getLocation('Asia/Tokyo');
      final now = tz.TZDateTime(tokyo, 2026, 10, 14, 10, 0);
      final when = nextDaily(now, 20 * 60);
      expect(when.location, tokyo);
      expect(when.hour, 20);
    });
  });

  // ---------------------------------------------------------------------
  // Weekly
  //
  // 2026-10-14 is a Wednesday. Sunday of that week is 2026-10-18.
  // Monday of next week is 2026-10-19.
  // ---------------------------------------------------------------------
  group('nextWeekly', () {
    test('before this week\'s day -> this week', () {
      final now = at(2026, 10, 14, 10, 0); // Wed
      expect(
        nextWeekly(now, DateTime.sunday, 20 * 60),
        at(2026, 10, 18, 20, 0),
      );
    });

    test('on the day, before the time -> today', () {
      final now = at(2026, 10, 18, 10, 0); // Sun 10:00
      expect(
        nextWeekly(now, DateTime.sunday, 20 * 60),
        at(2026, 10, 18, 20, 0),
      );
    });

    test('on the day, after the time -> next week', () {
      final now = at(2026, 10, 18, 21, 0); // Sun 21:00
      expect(
        nextWeekly(now, DateTime.sunday, 20 * 60),
        at(2026, 10, 25, 20, 0),
      );
    });

    test('on the day, exactly at the time -> next week', () {
      // Same strictness as nextDaily: rescheduling at the exact minute
      // shouldn't duplicate the just-fired notification.
      final now = at(2026, 10, 18, 20, 0); // Sun 20:00
      expect(
        nextWeekly(now, DateTime.sunday, 20 * 60),
        at(2026, 10, 25, 20, 0),
      );
    });

    test('every weekday is reachable from a Wednesday', () {
      final now = at(2026, 10, 14, 10, 0); // Wed
      // Later this week.
      expect(nextWeekly(now, DateTime.thursday, 20 * 60), at(2026, 10, 15, 20, 0));
      expect(nextWeekly(now, DateTime.friday, 20 * 60), at(2026, 10, 16, 20, 0));
      expect(nextWeekly(now, DateTime.saturday, 20 * 60), at(2026, 10, 17, 20, 0));
      expect(nextWeekly(now, DateTime.sunday, 20 * 60), at(2026, 10, 18, 20, 0));
      // Next week.
      expect(nextWeekly(now, DateTime.monday, 20 * 60), at(2026, 10, 19, 20, 0));
      expect(nextWeekly(now, DateTime.tuesday, 20 * 60), at(2026, 10, 20, 20, 0));
      // Wednesday today, but the time is in the past, so it rolls a full week.
      expect(nextWeekly(now, DateTime.wednesday, 8 * 60), at(2026, 10, 21, 8, 0));
      // Wednesday today, before the time, would be today — checked
      // separately above; keeping this one purely about the roll.
    });

    test('crossing a month boundary', () {
      // Sun 2026-11-01, after the time; next Sunday is 8 Nov.
      final now = at(2026, 11, 1, 22, 0);
      expect(
        nextWeekly(now, DateTime.sunday, 20 * 60),
        at(2026, 11, 8, 20, 0),
      );
    });

    test('crossing a year boundary', () {
      // Sun 2026-12-27, after the time; next Sunday is 3 Jan 2027.
      final now = at(2026, 12, 27, 22, 0);
      expect(
        nextWeekly(now, DateTime.sunday, 20 * 60),
        at(2027, 1, 3, 20, 0),
      );
    });

    test('always within the next 8 days for every (weekday, time)', () {
      // A quick sweep so a future refactor can't quietly turn the "8 day"
      // guard into "7 day" and break the worst-case path (asking for
      // today's weekday at a time already in the past).
      final now = at(2026, 10, 14, 12, 0); // Wed noon
      final horizon = now.add(const Duration(days: 8));
      for (var wd = 1; wd <= 7; wd++) {
        for (final minute in const [0, 8 * 60, 12 * 60, 20 * 60, 23 * 60 + 59]) {
          final when = nextWeekly(now, wd, minute);
          expect(when.weekday, wd, reason: 'weekday $wd @ $minute');
          expect(when.isAfter(now), isTrue, reason: 'weekday $wd @ $minute');
          expect(when.isBefore(horizon), isTrue, reason: 'weekday $wd @ $minute');
        }
      }
    });
  });

  // ---------------------------------------------------------------------
  // Monthly
  //
  // The settings model bounds the day to 1..28 so every month has it.
  // ---------------------------------------------------------------------
  group('nextMonthly', () {
    test('mid-month, asking for day 1 -> next month', () {
      final now = at(2026, 10, 15, 10, 0);
      expect(nextMonthly(now, 1, 20 * 60), at(2026, 11, 1, 20, 0));
    });

    test('on the day, before the time -> today', () {
      final now = at(2026, 10, 1, 10, 0);
      expect(nextMonthly(now, 1, 20 * 60), at(2026, 10, 1, 20, 0));
    });

    test('on the day, after the time -> next month', () {
      final now = at(2026, 10, 1, 22, 0);
      expect(nextMonthly(now, 1, 20 * 60), at(2026, 11, 1, 20, 0));
    });

    test('on the day, exactly at the time -> next month', () {
      final now = at(2026, 10, 1, 20, 0);
      expect(nextMonthly(now, 1, 20 * 60), at(2026, 11, 1, 20, 0));
    });

    test('crossing a year boundary', () {
      final now = at(2026, 12, 15, 10, 0);
      expect(nextMonthly(now, 1, 20 * 60), at(2027, 1, 1, 20, 0));
    });

    test('any day 1..28 lands on that exact day of the next month, never skipped',
            () {
          // The 1..28 bound is the whole reason monthly summaries can't
          // silently skip February. This sweep makes the guarantee explicit
          // for every allowed day.
          //
          // `now` is the last day of January at 23:00 so that every allowed
          // day d at noon is already in the past *this* month — that is the
          // only way to assert "every d rolls to February" as a single
          // statement. From an earlier `now`, days ≥ today's would correctly
          // stay in January, which is right but not what this sweep is
          // about.
          final now = at(2026, 1, 31, 23, 0);
          for (var d = 1; d <= 28; d++) {
            final when = nextMonthly(now, d, 12 * 60);
            expect(when.month, 2, reason: 'day $d');
            expect(when.day, d, reason: 'day $d');
            expect(when.isAfter(now), isTrue, reason: 'day $d');
          }
        });

    test('February 2026 has every allowed day', () {
      // Feb 2026 is not a leap year; 28 is the last day, so day 28 must
      // still fire within February rather than overflowing into March.
      //
      // Same precondition as the sweep above: `now` is late enough on
      // 31 Jan that every d rolls forward into February, so "the month
      // is February" is a statement about day d, not about when the test
      // happened to run.
      final now = at(2026, 1, 31, 23, 0);
      for (var d = 1; d <= 28; d++) {
        final when = nextMonthly(now, d, 12 * 60);
        expect(when.month, 2, reason: 'day $d');
      }
    });

    test('asking for a day already past this month rolls to next month', () {
      final now = at(2026, 10, 20, 10, 0); // 20 Oct
      expect(nextMonthly(now, 15, 20 * 60), at(2026, 11, 15, 20, 0));
    });

    test('a day still ahead of `now` this month stays this month', () {
      // The mirror of "already past this month rolls to next month".
      // Day 15 at noon, from the 15th at 10:00: still ahead, so it fires
      // today, not in November.
      final now = at(2026, 10, 15, 10, 0);
      expect(nextMonthly(now, 15, 12 * 60), at(2026, 10, 15, 12, 0));
    });
  });

  // ---------------------------------------------------------------------
  // Wall-clock behaviour across a DST transition.
  //
  // The helpers build a TZDateTime at (year, month, day, hour, minute) in
  // a *location*, and that constructor interprets its arguments as
  // wall-clock. So "20:00" stays 20:00 across a DST shift — which is what
  // we want: a summary scheduled for 8pm is at 8pm, not "8pm ± an hour,
  // whatever the offset happened to be when we scheduled it."
  //
  // Africa/Nairobi has no DST, so this case uses London, which does.
  // ---------------------------------------------------------------------
  group('wall-clock across DST', () {
    test('a Sunday 20:00 in London stays 20:00 across the spring-forward', () {
      final london = tz.getLocation('Europe/London');
      // 2026-03-29 is the UK spring-forward Sunday (last Sunday of March).
      // Sat 28 Mar 22:00 asking for the next Sunday 20:00 must return
      // 29 Mar 20:00 — one hour later in UTC than a plain 24h add would
      // give, because that day is only 23 hours long.
      final now = tz.TZDateTime(london, 2026, 3, 28, 22, 0);
      final when = nextWeekly(now, DateTime.sunday, 20 * 60);
      expect(when.year, 2026);
      expect(when.month, 3);
      expect(when.day, 29);
      expect(when.hour, 20);
      expect(when.minute, 0);
    });

    test('a next-day time in London keeps its wall-clock hour across the shift',
            () {
          final london = tz.getLocation('Europe/London');
          // Sat 28 Mar 22:00 asking for the next 20:00 gives 29 Mar 20:00 —
          // after the 1am transition, so the wall-clock hour is still 20, not
          // 21.
          final now = tz.TZDateTime(london, 2026, 3, 28, 22, 0);
          final when = nextDaily(now, 20 * 60);
          expect(when.day, 29);
          expect(when.hour, 20);
        });
  });
}