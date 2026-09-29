package com.kinyuanexus.fuata.fuata

import android.content.Context
import android.content.SharedPreferences

/**
 * Small native-side store for the two things the listener service needs
 * when the Dart side is not running (issue #22):
 *
 *  - the Dart callback handle for the background entry point, and
 *  - a mirror of the notification allow-list.
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

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}