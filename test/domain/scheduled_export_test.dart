import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/scheduled_export.dart';
import 'package:fuata/domain/models/settings.dart';

void main() {
  group('nextScheduledExportTrigger — daily', () {
    test('before the time today -> today', () {
      final now = DateTime(2026, 10, 17, 10, 0); // Sat
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.daily,
          minuteOfDay: 20 * 60,
          weekday: 1,
          now: now,
        ),
        DateTime(2026, 10, 17, 20, 0),
      );
    });

    test('at exactly the time -> tomorrow', () {
      final now = DateTime(2026, 10, 17, 20, 0);
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.daily,
          minuteOfDay: 20 * 60,
          weekday: 1,
          now: now,
        ),
        DateTime(2026, 10, 18, 20, 0),
      );
    });

    test('month boundary', () {
      final now = DateTime(2026, 10, 31, 23, 0);
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.daily,
          minuteOfDay: 20 * 60,
          weekday: 1,
          now: now,
        ),
        DateTime(2026, 11, 1, 20, 0),
      );
    });

    test('year boundary', () {
      final now = DateTime(2026, 12, 31, 23, 0);
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.daily,
          minuteOfDay: 20 * 60,
          weekday: 1,
          now: now,
        ),
        DateTime(2027, 1, 1, 20, 0),
      );
    });
  });

  group('nextScheduledExportTrigger — weekly', () {
    // Sat 17 Oct 2026.
    final now = DateTime(2026, 10, 17, 10, 0);

    test('a later weekday this week', () {
      // Sunday = 7 in Dart's weekday.
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.weekly,
          minuteOfDay: 20 * 60,
          weekday: DateTime.sunday,
          now: now,
        ),
        DateTime(2026, 10, 18, 20, 0),
      );
    });

    test('an earlier weekday rolls to next week', () {
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.weekly,
          minuteOfDay: 20 * 60,
          weekday: DateTime.monday,
          now: now,
        ),
        DateTime(2026, 10, 19, 20, 0),
      );
    });

    test('same weekday, time in the past -> next week', () {
      final later = DateTime(2026, 10, 17, 21, 0);
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.weekly,
          minuteOfDay: 20 * 60,
          weekday: DateTime.saturday,
          now: later,
        ),
        DateTime(2026, 10, 24, 20, 0),
      );
    });

    test('same weekday, time still ahead -> today', () {
      final earlier = DateTime(2026, 10, 17, 8, 0);
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.weekly,
          minuteOfDay: 20 * 60,
          weekday: DateTime.saturday,
          now: earlier,
        ),
        DateTime(2026, 10, 17, 20, 0),
      );
    });

    test('crosses a month end', () {
      final lastSat = DateTime(2026, 10, 31, 22, 0);
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.weekly,
          minuteOfDay: 20 * 60,
          weekday: DateTime.sunday,
          now: lastSat,
        ),
        DateTime(2026, 11, 1, 20, 0),
      );
    });

    test('crosses a year end', () {
      final endOfYear = DateTime(2026, 12, 26, 22, 0); // Sat
      expect(
        nextScheduledExportTrigger(
          frequency: ScheduledExportFrequency.weekly,
          minuteOfDay: 20 * 60,
          weekday: DateTime.sunday,
          now: endOfYear,
        ),
        DateTime(2026, 12, 27, 20, 0),
      );
    });
  });

  group('scheduledExportIntervalMs', () {
    test('daily is 24 hours', () {
      expect(
        scheduledExportIntervalMs(ScheduledExportFrequency.daily),
        const Duration(days: 1).inMilliseconds,
      );
    });
    test('weekly is 7 days', () {
      expect(
        scheduledExportIntervalMs(ScheduledExportFrequency.weekly),
        const Duration(days: 7).inMilliseconds,
      );
    });
  });

  group('scheduledExportFileName', () {
    test('a fixed moment formats exactly', () {
      expect(
        scheduledExportFileName(DateTime(2026, 10, 17, 20, 15, 33)),
        'fuata-backup-20261017-201533.json.enc',
      );
    });
    test('single digits are zero-padded', () {
      expect(
        scheduledExportFileName(DateTime(2026, 1, 5, 8, 3, 4)),
        'fuata-backup-20260105-080304.json.enc',
      );
    });
  });
}