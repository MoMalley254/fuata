// ---------------------------------------------------------------------------
// Claiming the alerts that are due (issue #63, US-06).
//
// Depends only on repository interfaces, so — like banner_loader.dart — it
// runs unchanged in the UI isolate and in the notification listener's
// background isolate.
//
// "Claim" is the important word. Both isolates can notice the same
// transaction at nearly the same moment (the background isolate writes it,
// the UI isolate's streams then fire). Each one asks the log to claim the
// alert *before* showing it; the log grants a claim to exactly one caller,
// so a limit crossed once is announced once.
// ---------------------------------------------------------------------------

import '../models/limit_alert.dart';
import '../repositories/repositories.dart';
import 'alert_engine.dart';

class AlertBatch {
  /// Alerts this caller has claimed and must now show.
  final List<LimitAlert> alerts;

  /// True inside quiet hours: show them, but without sound or a heads-up.
  final bool quiet;

  /// Mirrors the person's lock-screen privacy choice.
  final bool redactOnLockScreen;

  const AlertBatch({
    required this.alerts,
    required this.quiet,
    required this.redactOnLockScreen,
  });

  static const none = AlertBatch(
    alerts: [],
    quiet: false,
    redactOnLockScreen: true,
  );
}

/// How long a firing record is kept. Only the current period matters for
/// "once per period"; older rows are just clutter.
const alertLogRetention = Duration(days: 90);

Future<AlertBatch> claimDueAlerts({
  required UnitRepository units,
  required TransactionRepository transactions,
  required LimitRepository limits,
  required SettingsRepository settings,
  required AlertLogRepository log,
  DateTime Function()? now,
}) async {
  final clock = now ?? DateTime.now;
  final s = await settings.watchSettings().first;
  if (!s.alertsEnabled) return AlertBatch.none;

  final at = clock();
  final due = AlertEngine.due(
    limits: await limits.watchLimits().first,
    units: await units.watchUnits().first,
    transactions: await transactions.watchTransactions().first,
    fired: await log.firedKeys(),
    now: at,
  );
  if (due.isEmpty) return AlertBatch.none;

  final claimed = <LimitAlert>[];
  for (final alert in due) {
    // Claim every level this alert uses up, top level last: the top one
    // decides whether *we* won. Lower levels are recorded so a nudge
    // can't turn up after an "over" for the same limit and period.
    for (final key in alert.consumedKeys.where((k) => k != alert.key)) {
      await log.claim(key, at);
    }
    if (await log.claim(alert.key, at)) claimed.add(alert);
  }

  if (claimed.isNotEmpty) await log.purgeBefore(at.subtract(alertLogRetention));

  return AlertBatch(
    alerts: claimed,
    quiet: s.quietHoursEnabled &&
        QuietHours.contains(
          startMinute: s.quietStartMinute,
          endMinute: s.quietEndMinute,
          at: at,
        ),
    redactOnLockScreen: s.redactedLockScreenBanner,
  );
}
