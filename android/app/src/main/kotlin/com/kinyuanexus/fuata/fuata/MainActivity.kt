package com.kinyuanexus.fuata.fuata

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the UI engine and wires its native channels:
 *  - `fuata/share_intake` (issue #21): text shared in from other apps.
 *  - `fuata/capture` (issue #22): notification-access status, the
 *    allow-list mirror, the installed-apps picker, and the "captures
 *    changed" ping. Replaces the #18 spike's `fuata/listener_spike`.
 */
class MainActivity : FlutterActivity() {
    private var shareIntake: ShareIntakeChannel? = null
    private var captureChannel: CaptureChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        captureChannel = CaptureChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        shareIntake = ShareIntakeChannel(flutterEngine.dartExecutor.binaryMessenger)

        // The intent that started (or restarted) this activity may be a
        // share; route it now that the channel exists.
        shareIntake?.handleShareIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        captureChannel?.dispose()
        captureChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // singleTop: shares into a running activity arrive here.
        shareIntake?.handleShareIntent(intent)
    }
}
