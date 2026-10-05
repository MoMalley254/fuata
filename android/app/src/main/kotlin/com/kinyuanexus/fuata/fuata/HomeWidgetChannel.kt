package com.kinyuanexus.fuata.fuata

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `fuata/home_widget` channel: issue #29. Dart pushes a small data
 * snapshot; this writes it and asks the widget provider to redraw.
 *
 *  - `update {amount, currency, caption, progress, emoji, status}` -> null
 *  - `clear`                                                       -> null
 */
class HomeWidgetChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("bad_args", "Expected a map", null)
                        return@setMethodCallHandler
                    }
                    @Suppress("UNCHECKED_CAST")
                    WidgetDataStore.write(context, args as Map<String, Any?>)
                    FuataWidgetProvider.refreshAll(context)
                    result.success(null)
                }

                "clear" -> {
                    WidgetDataStore.clear(context)
                    FuataWidgetProvider.refreshAll(context)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "fuata/home_widget"
    }
}