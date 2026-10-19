package com.kinyuanexus.fuata

import android.content.Intent
// Issue #28: FlutterFragmentActivity, not FlutterActivity — local_auth
// drives AndroidX BiometricPrompt, which requires its host to be a
// FragmentActivity. On a plain Activity it fails with
// uiUnavailable/"the current activity must be a FragmentActivity".
// FlutterFragmentActivity is the same Flutter delegate in a Fragment
// host, so every channel below is unaffected.
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the UI engine and wires its native channels:
 *  - `fuata/share_intake` (issue #21): text shared in from other apps.
 *  - `fuata/capture` (issue #22): notification-access status, the
 *    allow-list mirror, the installed-apps picker, and the "captures
 *    changed" ping. Replaces the #18 spike's `fuata/listener_spike`.
 *  - `fuata/backup_files` (issue #24): save / open a JSON backup through
 *    the system file picker.
 */
class MainActivity : FlutterFragmentActivity() {
    private var shareIntake: ShareIntakeChannel? = null
    private var captureChannel: CaptureChannel? = null
    private var backupFiles: BackupFilesChannel? = null

    private var homeWidget: HomeWidgetChannel? = null

    private var privacy: PrivacyChannel? = null   // issue #84

    private var scheduledExport: ScheduledExportChannel? = null  // #35

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        captureChannel = CaptureChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        // Issue #84: takes `this` — the window flag is on this Activity's
        // window, not on the application context.
        privacy = PrivacyChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        homeWidget = HomeWidgetChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        shareIntake = ShareIntakeChannel(flutterEngine.dartExecutor.binaryMessenger)

        backupFiles = BackupFilesChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        scheduledExport = ScheduledExportChannel(
            this, flutterEngine.dartExecutor.binaryMessenger,
        )

        // The intent that started (or restarted) this activity may be a
        // share; route it now that the channel exists.
        shareIntake?.handleShareIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        captureChannel?.dispose()
        captureChannel = null
        privacy?.dispose()
        privacy = null
        homeWidget?.dispose()
        homeWidget = null
        backupFiles?.dispose()
        backupFiles = null
        scheduledExport?.dispose()
        scheduledExport = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Our picker results are consumed here; everything else (plugins)
        // goes on to Flutter's own handling.
        if (backupFiles?.handleActivityResult(requestCode, resultCode, data) == true) return
        if (scheduledExport?.handleActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // singleTop: shares into a running activity arrive here.
        shareIntake?.handleShareIntent(intent)
    }
}