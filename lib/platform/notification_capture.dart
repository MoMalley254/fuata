// ---------------------------------------------------------------------------
// Notification capture (issue #22) — replaces the #18 spike
// (listener_spike.dart, now deleted).
//
// Two halves live here:
//
//  * UI-isolate API: register the background entry point with Android,
//    mirror the allow-list to the native side, check/open notification
//    access, list installed apps for the picker, and hear about captures
//    the background isolate wrote.
//
//  * The background entry point, `captureBackgroundDispatcher`: started by
//    NotificationListener.kt / CaptureEngine.kt in its own FlutterEngine
//    when an allow-listed notification arrives — possibly while the app is
//    fully closed. It runs the same CaptureProcessor the UI runs.
//
// Privacy: notification text only ever travels native -> this isolate ->
// CaptureProcessor. It is never logged here, and nothing is stored unless
// the package is an enabled capture source (US-10).
// ---------------------------------------------------------------------------
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fuata/platform/widget_bridge.dart';

import '../data/constants/method_channels_constants.dart';
import '../data/db/app_database.dart';
import '../data/db/drift_repositories.dart';
import '../domain/logic/alert_engine.dart';
import '../domain/logic/banner_loader.dart';
import '../domain/logic/capture_notification_content.dart';
import '../domain/logic/capture_pipeline.dart';
import '../domain/logic/serial_queue.dart';
import '../domain/logic/widget_content.dart';
import 'alerts.dart';
import 'banner.dart';

const _channel = MethodChannel(captureMethodName);

/// One launchable app, as offered in the allow-list picker.
class InstalledApp {
  final String packageName;
  final String label;
  const InstalledApp({required this.packageName, required this.label});
}

// --- UI isolate ---------------------------------------------------------

/// Call once from `main()` on every start. Registers the background entry
/// point below with Android so the listener service can find it again
/// from a process that never ran Dart's `main()` (app swiped away).
///
/// The handle is only valid for the build that produced it, so it is
/// re-registered on every launch. After an app *update*, capture resumes
/// once the app has been opened once.
Future<void> registerCaptureCallback() async {
  final handle = PluginUtilities.getCallbackHandle(captureBackgroundDispatcher);
  if (handle == null) {
    // Only happens if the dispatcher loses its vm:entry-point pragma.
    debugPrint('[capture] could not obtain a callback handle');
    return;
  }
  try {
    await _channel.invokeMethod('setCallbackHandle', handle.toRawHandle());
  } on MissingPluginException {
    // Widget tests / non-Android: no native side.
  }
}

/// Opens Android's notification-access screen. On some phones (see
/// design.md 5.1, MIUI) the grant only takes effect when switched off and
/// on again *there* — the UI copy tells the person so.
Future<void> openNotificationAccessSettings() async {
  try {
    await _channel.invokeMethod('openNotificationAccessSettings');
  } on MissingPluginException {
    // no native side
  }
}

/// Whether the person has granted Fuata notification access. This is the
/// *grant*, not proof the service is bound (design.md 5.1) — detecting a
/// granted-but-unbound listener is #36.
Future<bool> isNotificationAccessEnabled() async {
  try {
    return await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Mirrors the allow-list to the native listener so it can discard a
/// non-allowed notification *before* it wakes Dart. The database's
/// capture_sources table stays the source of truth; this is a cache, and
/// CaptureProcessor.captureNotification re-checks the database anyway.
Future<void> setAllowedPackages(Iterable<String> packages) async {
  try {
    await _channel.invokeMethod('setAllowedPackages', packages.toList());
  } on MissingPluginException {
    // no native side
  }
}

/// Launchable apps on the phone, for the picker. Uses a launcher-intent
/// `<queries>` entry rather than QUERY_ALL_PACKAGES, so Fuata never asks
/// for the broad "see every app" permission.
Future<List<InstalledApp>> listLaunchableApps() async {
  try {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listLaunchableApps',
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        if (m['packageName'] is String && m['label'] is String)
          InstalledApp(
            packageName: m['packageName']! as String,
            label: m['label']! as String,
          ),
    ];
  } on MissingPluginException {
    return const [];
  } on PlatformException {
    return const [];
  }
}

/// The background isolate writes through its *own* database connection, so
/// this isolate's drift streams don't hear about it. Native pings us when
/// a capture landed; [onChanged] is where the caller tells drift to re-run
/// its queries. Pass null to detach.
void listenForCaptureChanges(VoidCallback? onChanged) {
  if (onChanged == null) {
    _channel.setMethodCallHandler(null);
    return;
  }
  _channel.setMethodCallHandler((call) async {
    debugPrint('[capture] got ${call.method}');
    if (call.method == 'onCapturesChanged') onChanged();
    return null;
  });
}

// A second route into the UI isolate, for the capture notification's
// Accept / Discard buttons. Those run in the *plugin's* background engine,
// which has no `fuata/capture` channel to the UI, so the native ping above
// can't carry them. Isolates in one process can find each other by name, so
// the UI registers a port and the background handler pokes it.
const _uiPingPortName = 'fuata/capture_action_ping';
ReceivePort? _uiPingPort;

/// UI isolate: [onChanged] runs whenever a capture notification's button
/// changed the ledger from the background. Pass null to detach.
void listenForCaptureActionPings(VoidCallback? onChanged) {
  IsolateNameServer.removePortNameMapping(_uiPingPortName);
  _uiPingPort?.close();
  _uiPingPort = null;
  if (onChanged == null) return;
  final port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, _uiPingPortName);
  port.listen((_) => onChanged());
  _uiPingPort = port;
}

/// Background isolate: tell a running UI to re-query. A no-op when the app
/// isn't running — nobody has registered the port.
void pingUiAfterCaptureAction() {
  IsolateNameServer.lookupPortByName(_uiPingPortName)?.send(null);
}

// --- Background isolate -------------------------------------------------

/// The background entry point. Runs in its own isolate, in its own
/// FlutterEngine, started by CaptureEngine.kt — this is NOT the UI
/// isolate. `vm:entry-point` stops the AOT compiler tree-shaking a
/// function that's only ever reached from native code.
@pragma('vm:entry-point')
void captureBackgroundDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(captureBackgroundMethodName);
  final queue = SerialQueue();

  channel.setMethodCallHandler((call) async {
    if (call.method != 'onNotification') return null;
    final args = (call.arguments as Map).cast<String, Object?>();
    final packageName = args['packageName'] as String?;
    final text = args['text'] as String?;
    if (packageName == null || text == null) return false;

    // One notification at a time: capture is check-then-insert, and
    // native may hand us several at once (SMS + push for one payment).
    return queue.run(() => _captureOne(packageName, text));
  });

  // Tell the native side this isolate is alive and ready for
  // onNotification calls.
  channel.invokeMethod('backgroundIsolateReady');
}

/// Returns true when something was written (a pending/confirmed
/// transaction or an unparsed entry), so native knows whether to tell a
/// running UI to refresh.
Future<bool> _captureOne(String packageName, String text) async {
  // A connection per notification, closed straight after — the pattern
  // the #18 spike proved safe across two isolates on one file
  // (design.md 5.1). Closing also lets the connection's own isolate exit.
  final db = AppDatabase();
  try {
    final processor = CaptureProcessor(
      units: DriftUnitRepository(db),
      templates: DriftTemplateRepository(db),
      transactions: DriftTransactionRepository(db),
      captures: DriftCaptureRepository(db),
      sources: DriftCaptureSourceRepository(db),
      settings: DriftSettingsRepository(db),
    );
    final outcome = await processor.captureNotification(packageName, text);
    final wrote = outcome is Captured || outcome is CaptureUnparsed;
    if (wrote) {
      await refreshDerivedState(db);

      // The caught-payment notification: details plus Accept / Fix /
      // Discard. Only for a capture that is waiting for a check — an
      // auto-accepted one is already in the ledger. Its own try/catch for
      // the same reason as the others: the row is saved, so a notification
      // failure must never turn this capture into an error.
      if (outcome is Captured && !outcome.autoAccepted) {
        try {
          await announceCapture(db, outcome.transactionId);
        } catch (e) {
          debugPrint('[capture] notification failed: ${e.runtimeType}');
        }
      }
    }
    return wrote;
  } catch (e, st) {
    // Type only — an exception message could echo notification text.
    debugPrint('[capture] failed: ${e.runtimeType}\n$st');
    return false;
  } finally {
    await db.close();
  }
}

/// Everything that is derived from the ledger and shown outside the app:
/// the ongoing banner, limit alerts and the home-screen widget. Run after
/// *anything* in a background isolate changes the ledger — a capture
/// arriving, or a capture being accepted or discarded from its notification
/// — because the UI isolate can't see the write when the app is closed.
///
/// Each step has its own try/catch: a banner failure must not swallow an
/// alert, or the reverse, and none of them may undo a write that is already
/// saved. The UI isolate re-posts on next open.
Future<void> refreshDerivedState(AppDatabase db) async {
  // Issue #16: the ongoing banner has to be re-posted from *here* too —
  // this isolate is the only thing running when the app is closed, so the
  // UI isolate's bannerSyncProvider can't see the write.
  try {
    await _refreshBanner(db);
  } catch (e) {
    debugPrint('[capture] banner re-post failed: ${e.runtimeType}');
  }
  // Issue #63: same reasoning for limit alerts.
  try {
    await fireDueAlerts(
      units: DriftUnitRepository(db),
      transactions: DriftTransactionRepository(db),
      limits: DriftLimitRepository(db),
      outings: DriftOutingRepository(db),
      settings: DriftSettingsRepository(db),
      log: DriftAlertLogRepository(db),
    );
  } catch (e) {
    debugPrint('[capture] alert failed: ${e.runtimeType}');
  }
  // Issue #29: the home-screen widget.
  try {
    await _refreshWidget(db);
  } catch (e) {
    debugPrint('[capture] widget push failed: ${e.runtimeType}');
  }
}

/// Posts the "I caught this — Accept, Fix or Discard?" notification for a
/// freshly captured, pending transaction. Honours the person's switch (off
/// means nothing is posted), their hide-amounts and lock-screen choices and
/// their quiet hours.
///
/// Also the way a capture notification is *re-posted* (issue #152): after a
/// note or category is saved from its buttons, or "Add details" swaps them,
/// the handler calls this with [update] true and the notification changes in
/// place — rebuilt from the saved row, so it always shows what is really
/// stored. Returns false when there is no pending row left to announce (the
/// caller should then take the notification down).
Future<bool> announceCapture(
  AppDatabase db,
  String transactionId, {
  CaptureNotificationMode mode = CaptureNotificationMode.main,
  bool update = false,
}) async {
  final settings = await DriftSettingsRepository(db).watchSettings().first;
  if (!settings.captureNotificationsEnabled) return true;

  final all = await DriftTransactionRepository(db).watchTransactions().first;
  final tx = all.where((t) => t.id == transactionId).firstOrNull;
  if (tx == null || tx.isConfirmed) return false;
  final fees = all.where((t) => t.parentId == transactionId).toList();
  final units = await DriftUnitRepository(db).watchUnits().first;
  final unit = units.where((u) => u.id == tx.unitId).firstOrNull;
  final categories = await DriftCategoryRepository(db).watchCategories().first;
  final category = categories.where((c) => c.id == tx.categoryId).firstOrNull;

  // No categories to offer: the picker would be an empty notification.
  final choices = CaptureNotificationText.topCategories(
    categories: categories,
    transactions: all,
  );
  final effectiveMode =
      mode == CaptureNotificationMode.categories && choices.isEmpty
      ? CaptureNotificationMode.main
      : mode;

  final content = CaptureNotificationText.build(
    transaction: tx,
    fees: fees,
    unit: unit,
    amountsHidden: settings.amountsHidden,
    currencyCode: settings.currencyCode,
    category: category,
  );
  final quiet =
      settings.quietHoursEnabled &&
      QuietHours.contains(
        startMinute: settings.quietStartMinute,
        endMinute: settings.quietEndMinute,
        at: DateTime.now(),
      );
  await BannerPlatform.instance.showCapture(
    content,
    quiet: quiet,
    redactOnLockScreen: settings.redactedLockScreenBanner,
    mode: effectiveMode,
    categoryChoices: choices,
    update: update,
  );
  return true;
}

/// Rebuilds the banner from the same repositories the capture just wrote
/// through, and posts or cancels it. Runs the exact same
/// [loadBannerContent] the UI isolate does.
Future<void> _refreshBanner(AppDatabase db) async {
  final content = await loadBannerContent(
    units: DriftUnitRepository(db),
    transactions: DriftTransactionRepository(db),
    limits: DriftLimitRepository(db),
    outings: DriftOutingRepository(db),
    settings: DriftSettingsRepository(db),
  );
  if (content == null) {
    await BannerPlatform.instance.cancel();
  } else {
    await BannerPlatform.instance.show(
      content,
      // Read once here from the *current* settings so the background
      // isolate sees the same lock-screen choice the UI isolate would.
      redactOnLockScreen: (await DriftSettingsRepository(
        db,
      ).watchSettings().first).redactedLockScreenBanner,
    );
  }
}

/// Rebuilds the home-screen widget's snapshot from the same repositories
/// the capture just wrote through. Issue #29; the widget has no other
/// source of truth when the app is closed.
/// Rebuilds the home-screen widget's snapshot from the same repositories
/// the capture just wrote through — via the shared loader, so the two
/// isolates can never disagree about what the widget says (issue #29,
/// options #113).
Future<void> _refreshWidget(AppDatabase db) async {
  final snapshot = await loadWidgetSnapshot(
    units: DriftUnitRepository(db),
    transactions: DriftTransactionRepository(db),
    limits: DriftLimitRepository(db),
    settings: DriftSettingsRepository(db),
  );
  await AndroidHomeWidgetBridge().push(snapshot);
}

/// Opens Android's per-app notification settings for Fuata (F15: the
/// "Android is blocking Fuata's notifications" warning on the Banner
/// screen). Distinct from [openNotificationAccessSettings], which is the
/// special-access list for the listener.
Future<void> openAppNotificationSettings() async {
  try {
    await _channel.invokeMethod('openAppNotificationSettings');
  } on MissingPluginException {
    // no native side
  }
}
