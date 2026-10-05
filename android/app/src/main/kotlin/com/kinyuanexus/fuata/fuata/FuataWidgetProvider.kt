package com.kinyuanexus.fuata.fuata

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * The home-screen widget (issue #29): a small at-a-glance card matching
 * the notification banner — status emoji, big number, caption, optional
 * progress bar. Tap opens the app.
 *
 * A plain BroadcastReceiver: it runs in the app process, has no Flutter
 * engine, and reads only what HomeWidgetChannel last wrote to
 * WidgetDataStore. Every render is the same code path, so an update from
 * Dart and an update from the launcher's own periodic refresh look
 * identical.
 *
 * Colours come from @color / @color-night resources rather than Flutter's
 * ThemeExtension — RemoteViews can't read Flutter-side state, and the
 * status colour is the only thing that changes with the data.
 */
class FuataWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        val snapshot = WidgetDataStore.read(context)
        for (id in ids) {
            manager.updateAppWidget(id, buildViews(context, snapshot))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        // A resize can change padding and available width; re-render so
        // the amount never overlaps the caption.
        manager.updateAppWidget(id, buildViews(context, WidgetDataStore.read(context)))
    }

    private fun buildViews(
        context: Context,
        snapshot: WidgetDataStore.Snapshot?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.fuata_widget)

        if (snapshot == null) {
            // Same warm-empty voice the app uses, rather than a blank
            // card the person can't act on.
            views.setTextViewText(R.id.widget_emoji, "👋")
            views.setTextViewText(R.id.widget_amount, "—")
            views.setTextViewText(R.id.widget_currency, "")
            views.setTextViewText(R.id.widget_caption, "open Fuata")
            views.setViewVisibility(R.id.widget_progress, View.GONE)
        } else {
            views.setTextViewText(R.id.widget_emoji, snapshot.emoji)
            views.setTextViewText(R.id.widget_amount, snapshot.amount)
            views.setTextViewText(R.id.widget_currency, snapshot.currency)
            views.setTextViewText(R.id.widget_caption, snapshot.caption)
            views.setTextColor(R.id.widget_caption, statusColour(context, snapshot.status))

            if (snapshot.progress in 0.0..1.0) {
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                views.setInt(
                    R.id.widget_progress,
                    "setProgress",
                    (snapshot.progress * 100).toInt(),
                )
            } else {
                views.setViewVisibility(R.id.widget_progress, View.GONE)
            }
        }

        // Tap = open the app, singleTop, so an already-running app comes
        // to the foreground rather than starting a second copy.
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        if (launch != null) {
            val pending = PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
        }

        return views
    }

    private fun statusColour(context: Context, status: String): Int =
        context.getColor(
            when (status) {
                "warning" -> R.color.status_warning
                "danger" -> R.color.status_danger
                "overdraft" -> R.color.status_overdraft
                else -> R.color.status_safe
            },
        )

    companion object {
        /** Called from HomeWidgetChannel after every Dart-side write. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, FuataWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, FuataWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}