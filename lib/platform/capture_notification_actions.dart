// ---------------------------------------------------------------------------
// The buttons on a caught-payment notification (see BannerPlatform.showCapture).
//
// Accept and Discard do exactly what "Looks right" and "Not mine" do in the
// review inbox — via the same CaptureReview — but without opening the app.
// Android hands the press to [captureNotificationBackgroundHandler], which
// runs in its own background isolate, possibly with the UI process asleep or
// never started. Fix is the one button that needs the app (it is an edit
// form), so it is *not* handled here: it launches the app onto the Fix sheet
// (BannerPlatform.captureTaps, handled in main.dart).
//
// What a press does, start to finish:
//   1. open a database connection (one per press, closed straight after —
//      the pattern the capture isolate uses; see notification_capture.dart),
//   2. accept or discard through CaptureReview,
//   3. refresh everything derived from the ledger that shows outside the app
//      (banner, limit alerts, home-screen widget), because the ledger just
//      changed and the UI isolate may not be running to notice,
//   4. poke a running UI so Home, Activity and the inbox re-query.
//
// Android removes the notification itself the moment a button is pressed
// (cancelNotification: true), so a double press can't double-act — and
// CaptureReview only ever acts on a *pending* row, so a stale button can't
// touch money already confirmed in the app.
//
// Nothing here logs amounts, text or ids — only exception types.
// ---------------------------------------------------------------------------
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/db/app_database.dart';
import '../data/db/drift_repositories.dart';
import '../domain/logic/capture_notification_content.dart';
import '../domain/logic/capture_review.dart';
import 'banner.dart';
import 'notification_capture.dart';

/// Registered with the notification plugin in [BannerPlatform.init]. Must be
/// a top-level function, and `vm:entry-point` stops the AOT compiler
/// tree-shaking something only native code ever calls.
@pragma('vm:entry-point')
Future<void> captureNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  // This isolate never ran main(): make plugins (path_provider, sqlcipher)
  // reachable before the database is opened.
  DartPluginRegistrant.ensureInitialized();
  await handleCaptureNotificationResponse(response);
}

/// Split from the entry point so it reads as ordinary code. Public for
/// tests; never throws — a failure here has nobody to tell.
Future<void> handleCaptureNotificationResponse(
  NotificationResponse response,
) async {
  final transactionId = CaptureNotificationTap.transactionIdFrom(
    response.payload,
  );
  if (transactionId == null) return;

  switch (response.actionId) {
    case BannerPlatform.captureAcceptAction:
      await _run(() => _accept(transactionId));
    case BannerPlatform.captureDiscardAction:
      await _run(() => _discard(transactionId));
    default:
      // Fix / Update balance / a body tap open the app and are handled in
      // the UI isolate. Nothing to do in the background.
      return;
  }
}

Future<void> _run(Future<void> Function() body) async {
  try {
    await body();
  } catch (e) {
    // Type only — a message could echo what was on the notification.
    debugPrint('[capture-action] failed: ${e.runtimeType}');
  }
}

Future<void> _accept(String transactionId) async {
  final db = AppDatabase();
  try {
    final result = await CaptureReview(
      transactions: DriftTransactionRepository(db),
      units: DriftUnitRepository(db),
    ).accept(transactionId);
    if (!result.found) return; // already dealt with in the app

    await refreshDerivedState(db);
    pingUiAfterCaptureAction();

    // The in-app version of this is the "message says X, ledger says Y"
    // snackbar with an Update balance button. Here it is a follow-up
    // notification with the same button.
    if (result.balanceMismatch) {
      final settings = await DriftSettingsRepository(db).watchSettings().first;
      await BannerPlatform.instance.showBalanceMismatch(
        CaptureNotificationText.balanceMismatch(
          transactionId: transactionId,
          unit: result.unit!,
          quotedMinor: result.quotedBalanceMinor!,
          ledgerMinor: result.ledgerBalanceMinor!,
          amountsHidden: settings.amountsHidden,
        ),
        redactOnLockScreen: settings.redactedLockScreenBanner,
      );
    }
  } finally {
    await db.close();
  }
}

Future<void> _discard(String transactionId) async {
  final db = AppDatabase();
  try {
    final removed = await CaptureReview(
      transactions: DriftTransactionRepository(db),
      units: DriftUnitRepository(db),
    ).discard(transactionId);
    if (!removed) return;

    await refreshDerivedState(db);
    pingUiAfterCaptureAction();
  } finally {
    await db.close();
  }
}
