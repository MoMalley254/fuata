package com.kinyuanexus.fuata

import android.app.Notification

/**
 * Pulls the message text out of a notification (issue #22).
 *
 * Fixes the known gap from the #18 spike (design.md 5.1): the spike's
 * text ended up as `sbn.tag` on one device. This walks the notification's
 * own extras in a fixed, documented order and never touches `sbn.tag` or
 * `sbn.key` — those identify the notification, they are not its content.
 *
 * Order (first non-blank wins):
 *  1. EXTRA_BIG_TEXT    — the expanded body; the full message when the
 *                         app supplies one (usually the least truncated)
 *  2. EXTRA_TEXT        — the collapsed body
 *  3. EXTRA_TEXT_LINES  — inbox-style lines, joined with newlines
 *  4. EXTRA_SUB_TEXT    — secondary line
 *  5. tickerText        — legacy one-liner
 *  6. EXTRA_TITLE       — last resort: some apps put the whole message in
 *                         the title. It is NOT prepended to the body, so
 *                         the parser sees the same text a pasted SMS gives.
 *
 * The result is handed to Dart in memory only. It is never logged.
 */
object NotificationText {

    fun extract(notification: Notification): String? {
        val extras = notification.extras
        val candidates = sequenceOf(
            extras?.getCharSequence(Notification.EXTRA_BIG_TEXT),
            extras?.getCharSequence(Notification.EXTRA_TEXT),
            joinLines(extras?.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)),
            extras?.getCharSequence(Notification.EXTRA_SUB_TEXT),
            notification.tickerText,
            extras?.getCharSequence(Notification.EXTRA_TITLE),
        )
        return candidates
            .mapNotNull { it?.toString()?.trim() }
            .firstOrNull { it.isNotEmpty() }
    }

    private fun joinLines(lines: Array<CharSequence>?): CharSequence? {
        if (lines == null || lines.isEmpty()) return null
        return lines.joinToString("\n") { it.toString() }
    }
}
