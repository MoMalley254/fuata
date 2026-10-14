package com.kinyuanexus.fuata.fuata

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * The home-screen widget's cached snapshot (issue #29).
 *
 * Dart pushes a small map over `fuata/home_widget`; HomeWidgetChannel
 * writes it here and pings the widget provider to re-render. The
 * provider itself never talks to Dart and never touches the drift
 * database — it is a plain BroadcastReceiver and might run when no
 * Flutter engine is alive.
 *
 * Same pattern as CaptureStore: a small SharedPreferences cache the
 * native side can read instantly. `progress` is stored as -1.0 to mean
 * "no progress bar"; a real progress of 0 is legal and distinct.
 */
object WidgetDataStore {
    private const val PREFS = "fuata_widget"
    private const val KEY = "snapshot"
    const val NO_PROGRESS = -1.0

    data class Snapshot(
        val amount: String,
        val currency: String,
        val caption: String,
        val progress: Double,
        val emoji: String,
        val status: String,
        val splitLine: String,
        val variant: String,
    )

    fun write(context: Context, data: Map<String, Any?>) {
        val json = JSONObject(data).toString()
        prefs(context).edit().putString(KEY, json).apply()
    }

    fun read(context: Context): Snapshot? {
        val raw = prefs(context).getString(KEY, null) ?: return null
        return try {
            val o = JSONObject(raw)
            Snapshot(
                amount = o.optString("amount", "0"),
                currency = o.optString("currency", ""),
                caption = o.optString("caption", ""),
                progress = o.optDouble("progress", NO_PROGRESS),
                emoji = o.optString("emoji", ""),
                status = o.optString("status", "safe"),
                splitLine = o.optString("splitLine", ""),
                variant = o.optString("variant", "auto"),
            )
        } catch (_: Exception) {
            // A hand-edited or truncated row is one we can't render;
            // falling back to the empty state is better than crashing.
            null
        }
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY).apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}