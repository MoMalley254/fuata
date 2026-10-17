// ---------------------------------------------------------------------------
// Keeps the OS alarm in step with the person's schedule (issue #35).
//
// Same shape as bannerSyncProvider / alertSyncProvider: watch the
// settings, act whenever they move. Deliberately not scheduled unless
// folder + passphrase are both in place — arming an alarm that will
// always fail is noise; the settings screen shows why.
// ---------------------------------------------------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/scheduled_export.dart';
import '../../platform/scheduled_export.dart';
import 'app_providers.dart';

/// Last run's status (issue #35). Read once; invalidated by "Run now" and
/// by returning to the settings screen. Deliberately not a stream: a
/// scheduled background run won't notify the UI, and polling for a status
/// that changes twice a day is more machinery than the feature deserves.
final scheduledExportStatusProvider =
FutureProvider<ScheduledExportStatus>((ref) {
  return readScheduledExportStatus();
});

/// Watched once, from Fuata's build. The side effect *is* the provider.
final scheduledExportSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(currentSettingsProvider);

  // Wait for the first real settings value: defaulting to "off" while
  // loading would cancel an alarm the background isolate just armed.
  if (ref.watch(settingsProvider).isLoading) return;

  final folder = settings.scheduledExportFolderUri;
  final ready = settings.scheduledExportEnabled &&
      folder != null &&
      folder.isNotEmpty &&
      settings.scheduledExportPassphraseSet;

  if (!ready) {
    cancelScheduledExport();
    return;
  }

  final firstTrigger = nextScheduledExportTrigger(
    frequency: settings.scheduledExportFrequency,
    minuteOfDay: settings.scheduledExportMinute,
    weekday: settings.scheduledExportWeekday,
    now: DateTime.now(),
  );
  scheduleScheduledExport(
    firstTriggerAt: firstTrigger,
    intervalMs: scheduledExportIntervalMs(settings.scheduledExportFrequency),
  );
});