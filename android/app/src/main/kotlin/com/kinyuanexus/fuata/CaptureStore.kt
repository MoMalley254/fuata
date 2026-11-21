package com.kinyuanexus.fuata

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock

/**
 * Small native-side store for the things the listener service needs
 * when the Dart side is not running (issue #22, #36):
 *
 *  - the Dart callback handle for the background entry point,
 *  - a mirror of the notification allow-list, and
 *  - listener lifecycle timestamps (issue #36): when Android last bound
 *    and unbound the service, and when the grant was first seen. Times
 *    only — never notification content.
 *
 * The database (capture_sources) stays the source of truth; Dart pushes
 * its enabled rows here via [writeAllowedPackages] on every app start and
 * every change. It exists so a notification from an app the person has
 * NOT allowed can be dropped natively — before a Flutter engine is
 * started and before its text is read into Dart (US-10).
 */
object CaptureStore {
    private const val PREFS = "fuata_capture"
    private const val KEY_HANDLE = "callback_handle"
    private const val KEY_ALLOWED = "allowed_packages"
    private const val KEY_CONNECTED_AT = "listener_connected_at"
    private const val KEY_DISCONNECTED_AT = "listener_disconnected_at"
    private const val KEY_GRANTED_AT = "listener_granted_at"

    fun writeCallbackHandle(context: Context, handle: Long) {
        prefs(context).edit().putLong(KEY_HANDLE, handle).apply()
    }

    fun readCallbackHandle(context: Context): Long? {
        val v = prefs(context).getLong(KEY_HANDLE, -1L)
        return if (v == -1L) null else v
    }

    fun writeAllowedPackages(context: Context, packages: Collection<String>) {
        prefs(context).edit().putStringSet(KEY_ALLOWED, HashSet(packages)).apply()
    }

    /** False for everything until Dart has pushed a list: default is discard. */
    fun isAllowed(context: Context, packageName: String): Boolean {
        val allowed = prefs(context).getStringSet(KEY_ALLOWED, null) ?: return false
        return allowed.contains(packageName)
    }

    // --- Listener lifecycle (issue #36) ---------------------------------
    //
    // Android has no "is my listener bound right now?" API, so the service
    // records the two callbacks it does get. The status itself is computed
    // in Dart (lib/domain/logic/listener_status.dart) from these raw times.

    /** The service was bound by the system: it is genuinely able to hear notifications. */
    fun recordListenerConnected(context: Context, now: Long = System.currentTimeMillis()) {
        val e = prefs(context).edit().putLong(KEY_CONNECTED_AT, now)
        // A bound listener implies the grant. Stamp it here too, so a
        // connect that lands before the app next looks is not mistaken
        // for one from before the grant.
        if (!prefs(context).contains(KEY_GRANTED_AT)) e.putLong(KEY_GRANTED_AT, now)
        e.apply()
    }

    /**
     * The system unbound the service (revoked, killed, or rebound by the
     * OS). The grant time is cleared: whether it still holds is re-observed
     * by [observeGrant], which gives the status a fresh grace period.
     */
    fun recordListenerDisconnected(context: Context, now: Long = System.currentTimeMillis()) {
        prefs(context).edit()
            .putLong(KEY_DISCONNECTED_AT, now)
            .remove(KEY_GRANTED_AT)
            .apply()
    }

    /**
     * Called whenever the app reads the grant. Stamps "first seen granted"
     * once, and clears it when the grant is seen to be gone.
     */
    fun observeGrant(context: Context, granted: Boolean, now: Long = System.currentTimeMillis()) {
        val p = prefs(context)
        if (granted) {
            if (!p.contains(KEY_GRANTED_AT)) p.edit().putLong(KEY_GRANTED_AT, now).apply()
        } else if (p.contains(KEY_GRANTED_AT)) {
            p.edit().remove(KEY_GRANTED_AT).apply()
        }
    }

    /** Raw listener signals, epoch milliseconds; null when never recorded. */
    fun listenerSignals(context: Context): Map<String, Long?> {
        val p = prefs(context)
        fun read(key: String): Long? = if (p.contains(key)) p.getLong(key, 0L) else null
        return mapOf(
            "connectedAt" to read(KEY_CONNECTED_AT),
            "disconnectedAt" to read(KEY_DISCONNECTED_AT),
            "grantedAt" to read(KEY_GRANTED_AT),
            // Boot time = now - uptime. A connect recorded before it is
            // from a previous boot and says nothing about this one.
            "bootAt" to (System.currentTimeMillis() - SystemClock.elapsedRealtime()),
        )
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
