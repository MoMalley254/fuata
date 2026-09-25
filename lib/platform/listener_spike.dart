// ---------------------------------------------------------------------------
// Issue #18 — SPIKE, throwaway. Time-boxed to 2 hours.
//
// Goal (design.md section 5, "top project risk"): prove that a background
// isolate, started by Android when the app is fully closed, can open the
// *same* fuata.sqlite file the UI isolate has open and write a row safely.
//
// Deliberately minimal: no allow-list (#22), no template matching (#19),
// no dedupe. It logs exactly one UnparsedCaptures row per notification so
// the write path can be inspected afterwards. This file is replaced
// entirely by the real listener in #22 — do not build on top of it.
// ---------------------------------------------------------------------------
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data/db/app_database.dart';

const _spikeChannel = MethodChannel('fuata/listener_spike');

/// Call once from `main()` on every app start (UI isolate). Registers the
/// Dart entry point below with Android so the native side can find it
/// again later, from a process that never ran Dart's `main()` — i.e. when
/// Android starts the listener service after the app has been swiped away.
Future<void> registerListenerSpikeCallback() async {
  final handle = PluginUtilities.getCallbackHandle(_backgroundDispatcher);
  if (handle == null) {
    // Only happens if _backgroundDispatcher loses its @pragma below or is
    // torn out by tree-shaking — fail loud during the spike, not silently.
    print('[listener_spike] could not obtain a callback handle');
    return;
  }
  await _spikeChannel.invokeMethod('setCallbackHandle', handle.toRawHandle());
}

/// Opens Android's notification-access settings so the user can grant this
/// app special access. No permission_handler-style plugin for the spike —
/// just an implicit intent from the native side.
Future<void> openNotificationAccessSettings() async {
  _spikeChannel.invokeMethod('openNotificationAccessSettings');
}

/// The background entry point. Runs in its own isolate, in its own
/// FlutterEngine, started by NotificationListener.kt — this is NOT the UI
/// isolate. `vm:entry-point` stops the AOT compiler tree-shaking a
/// function that's only ever reached from native code.
@pragma('vm:entry-point')
void _backgroundDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fuata/listener_spike_bg');

  channel.setMethodCallHandler((call) async {
    if (call.method != 'onNotification') return null;
    final args = (call.arguments as Map).cast<String, Object?>();
    final packageName = args['packageName'] as String? ?? 'unknown';
    final text = args['text'] as String? ?? '';

    final stopwatch = Stopwatch()..start();
    // A *second* connection to the same file the UI isolate has open —
    // exactly the scenario design.md flags as the top risk: two isolates,
    // two AppDatabase instances, one fuata.sqlite.
    final db = AppDatabase();
    try {
      await db
          .into(db.unparsedCaptures)
          .insert(
        UnparsedCapturesCompanion.insert(
          id: 'spike-${DateTime.now().microsecondsSinceEpoch}',
          receivedAt: DateTime.now().toUtc(),
          sourcePackage: packageName,
          rawText: text,
        ),
      );
      print(
        '[listener_spike] wrote 1 row from $packageName '
            'in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      print('[listener_spike] FAILED to write: $e\n$st');
    } finally {
      await db.close();
    }
    return null;
  });

  // Tell the native side this isolate is alive and ready for onNotification.
  channel.invokeMethod('backgroundIsolateReady');
}