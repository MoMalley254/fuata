// ---------------------------------------------------------------------------
// Scheduled encrypted export (issue #35) — UI API and background entry point.
//
// Two halves, same shape as platform/notification_capture.dart:
//
//  * UI-isolate API: register the background callback, schedule / cancel
//    the alarm, pick the export folder, save an encrypted file now (the
//    "Run now" button), and read the last run's status.
//
//  * `scheduledExportDispatcher`: started by ScheduledExportReceiver.kt
//    in its own engine when the alarm fires. Reads the DB, builds the
//    backup, encrypts it with the cached passphrase, writes it to the
//    chosen folder, and reports success or a runtime-type-only failure.
//
// No amount or passphrase is ever logged here.
// ---------------------------------------------------------------------------
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/constants/method_channels_constants.dart';
import '../data/db/app_database.dart';
import '../data/db/backup_repository.dart';
import '../data/db/drift_repositories.dart';
import '../domain/logic/backup_crypto.dart';
import '../domain/logic/backup_service.dart';
import '../domain/logic/scheduled_export.dart';
import '../domain/models/settings.dart';
import 'backup_passphrase_store.dart';

const _channel = MethodChannel(scheduledExportMethodName);

// --- UI isolate ---------------------------------------------------------

class ScheduledExportStatus {
  /// Null when the schedule has never run since install.
  final DateTime? lastRunAt;
  final bool lastRunSuccess;

  /// Just the runtime type — never exception text. A scheduled run that
  /// fails has no context for a message, and the type is what a bug
  /// report needs.
  final String? lastRunError;

  const ScheduledExportStatus({
    this.lastRunAt,
    this.lastRunSuccess = false,
    this.lastRunError,
  });

  static const empty = ScheduledExportStatus();
}

/// Call once from main() on every start. Re-registers the callback handle
/// every launch — the handle is valid for one build.
Future<void> registerScheduledExportCallback() async {
  final handle =
  PluginUtilities.getCallbackHandle(scheduledExportDispatcher);
  if (handle == null) {
    debugPrint('[scheduled_export] could not obtain a callback handle');
    return;
  }
  try {
    await _channel
        .invokeMethod('setCallbackHandle', handle.toRawHandle());
  } on MissingPluginException {
    // Widget tests / non-Android.
  }
}

/// Arms (or re-arms) the alarm. [firstTriggerAt] is a wall-clock correct
/// first occurrence from `nextScheduledExportTrigger`; the OS then repeats
/// it at [intervalMs] and, after a reboot, the boot receiver re-arms from
/// saved state.
Future<void> scheduleScheduledExport({
  required DateTime firstTriggerAt,
  required int intervalMs,
}) async {
  try {
    await _channel.invokeMethod('schedule', {
      'triggerAtMillis': firstTriggerAt.toUtc().millisecondsSinceEpoch,
      'intervalMillis': intervalMs,
    });
  } on MissingPluginException {
    // no native side
  }
}

Future<void> cancelScheduledExport() async {
  try {
    await _channel.invokeMethod('cancel');
  } on MissingPluginException {
    // no native side
  }
}

/// Opens Android's folder picker, takes a persistable permission, and
/// returns the tree URI. Null when the person backs out.
Future<String?> pickScheduledExportFolder() async {
  try {
    return await _channel.invokeMethod<String>('pickFolder');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<bool> hasScheduledExportFolderPermission(String uri) async {
  try {
    return await _channel.invokeMethod<bool>(
      'hasPersistedFolder',
      {'uri': uri},
    ) ??
        false;
  } on MissingPluginException {
    return false;
  }
}

Future<String?> scheduledExportFolderName(String uri) async {
  try {
    return await _channel.invokeMethod<String>(
      'folderDisplayName',
      {'uri': uri},
    );
  } on MissingPluginException {
    return null;
  }
}

/// Releases the SAF permission for [uri] (the "change folder" flow calls
/// this before picking a new one; "clear folder" would too if added).
Future<void> clearScheduledExportFolder(String uri) async {
  try {
    await _channel.invokeMethod('clearFolder', {'uri': uri});
  } on MissingPluginException {
    // no native side
  }
}

/// Writes [content] to [filename] inside [folderUri]. Returns false on any
/// failure — the caller decides whether to surface a message.
Future<bool> writeToExportFolder({
  required String folderUri,
  required String filename,
  required String content,
}) async {
  try {
    return await _channel.invokeMethod<bool>('saveToFolder', {
      'uri': folderUri,
      'filename': filename,
      'content': content,
    }) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<ScheduledExportStatus> readScheduledExportStatus() async {
  try {
    final map =
    await _channel.invokeMapMethod<String, Object?>('lastRun');
    if (map == null) return ScheduledExportStatus.empty;
    final ms = map['at'] as int?;
    return ScheduledExportStatus(
      lastRunAt: ms == null || ms == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms),
      lastRunSuccess: (map['success'] as bool?) ?? false,
      lastRunError: map['error'] as String?,
    );
  } on MissingPluginException {
    return ScheduledExportStatus.empty;
  }
}

// --- Background isolate -------------------------------------------------

@pragma('vm:entry-point')
void scheduledExportDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire and forget. Any error is reported back to native, which records
  // it for the settings screen and then tears the engine down.
  _runExport().then((outcome) async {
    const ch = MethodChannel(scheduledExportBackgroundMethodName);
    try {
      await ch.invokeMethod('reportResult', {
        'success': outcome == null,
        if (outcome != null) 'error': outcome,
      });
    } on MissingPluginException {
      // no native side
    }
  });
}

/// Returns null on success, or the *runtime type* of the failure.
Future<String?> _runExport() async {
  AppDatabase? db;
  try {
    db = AppDatabase();
    final settings =
    await DriftSettingsRepository(db).watchSettings().first;
    final folderUri = settings.scheduledExportFolderUri;
    if (folderUri == null || folderUri.isEmpty) {
      return 'StateError';
    }

    final passphrase = await BackupPassphraseStore.read();
    if (passphrase == null) return 'StateError';

    final backup = await BackupService(DriftBackupRepository(db))
        .buildExport(includeRawText: settings.scheduledExportIncludeRawText);
    final encrypted =
    await BackupCrypto.encode(backup.json, passphrase: passphrase);

    const ch = MethodChannel(scheduledExportBackgroundMethodName);
    final ok = await ch.invokeMethod<bool>('saveToFolder', {
      'uri': folderUri,
      'filename': scheduledExportFileName(DateTime.now()),
      'content': encrypted,
    });
    if (ok != true) return 'PlatformException';
    return null;
  } catch (e) {
    // Type only — an exception message could echo data. See the doc on
    // ScheduledExportStatus.lastRunError.
    return e.runtimeType.toString();
  } finally {
    await db?.close();
  }
}