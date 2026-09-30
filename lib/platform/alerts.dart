// ---------------------------------------------------------------------------
// Limit alerts (issue #63, US-06): claim what is due, then show it.
//
// One function, called from both places that can see money change — the UI
// isolate (alert_providers.dart) and the notification listener's background
// isolate (notification_capture.dart). The claim in [claimDueAlerts] is what
// keeps them from announcing the same crossing twice.
//
// Nothing in here logs amounts or alert text.
// ---------------------------------------------------------------------------

import '../domain/logic/alert_service.dart';
import '../domain/repositories/repositories.dart';
import 'banner.dart';

Future<void> fireDueAlerts({
  required UnitRepository units,
  required TransactionRepository transactions,
  required LimitRepository limits,
  required SettingsRepository settings,
  required AlertLogRepository log,
}) async {
  final batch = await claimDueAlerts(
    units: units,
    transactions: transactions,
    limits: limits,
    settings: settings,
    log: log,
  );
  for (final alert in batch.alerts) {
    await BannerPlatform.instance.showAlert(
      alert,
      quiet: batch.quiet,
      redactOnLockScreen: batch.redactOnLockScreen,
    );
  }
}
