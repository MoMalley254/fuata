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
            manager.updateAppWidget(id, buildViews(context, id, snapshot))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        // A resize can change the variant: re-render so the split line
        // appears or disappears with the cell width (issue #113).
        manager.updateAppWidget(
            id,
            buildViews(context, id, WidgetDataStore.read(context)),
        )
    }

    private fun buildViews(
        context: Context,
        id: Int,
        snapshot: WidgetDataStore.Snapshot?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.fuata_widget)

        if (snapshot == null) {
            views.setTextViewText(R.id.widget_emoji, "👋")
            views.setTextViewText(R.id.widget_amount, "—")
            views.setTextViewText(R.id.widget_currency, "")
            views.setTextViewText(R.id.widget_caption, "open Fuata")
            views.setViewVisibility(R.id.widget_progress, View.GONE)
            views.setViewVisibility(R.id.widget_split_line, View.GONE)
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

            if (shouldShowSplit(context, id, snapshot)) {
                views.setViewVisibility(R.id.widget_split_line, View.VISIBLE)
                views.setTextViewText(R.id.widget_split_line, snapshot.splitLine)
            } else {
                views.setViewVisibility(R.id.widget_split_line, View.GONE)
            }
        }

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

    /**
     * Whether this instance shows the split line. A forced variant wins;
     * `auto` uses the minimum width the launcher reports, so a 2-cell
     * widget stays compact and a 3-cell one gets the split. The split
     * line is empty when the person switched it off or no unit is in the
     * widget's currency, and empty means hide.
     */
    private fun shouldShowSplit(
        context: Context,
        id: Int,
        snapshot: WidgetDataStore.Snapshot,
    ): Boolean {
        if (snapshot.splitLine.isEmpty()) return false
        return when (snapshot.variant) {
            "compact" -> false
            "rich" -> true
            else -> {
                val options = AppWidgetManager.getInstance(context)
                    .getAppWidgetOptions(id)
                val widthDp = options.getInt(
                    AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
                )
                widthDp >= RICH_MIN_WIDTH_DP
            }
        }
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
        /// Below this width (dp) the auto variant stays compact: the split
        /// line would either wrap or shrink to unreadable. Matches
        /// fuata_widget_info.xml's targetCellWidth of 3 — a two-cell
        /// widget is about 140-160 dp on most launchers, a three-cell one
        /// about 210-240.
        private const val RICH_MIN_WIDTH_DP = 200
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