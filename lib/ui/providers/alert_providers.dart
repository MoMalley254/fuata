// ---------------------------------------------------------------------------
// Firing limit alerts from the UI isolate (issue #63, US-06).
//
// Like bannerSyncProvider: watch the data, and act whenever it changes. What
// it does *not* handle is a capture written by the notification listener
// while the app is closed — that path fires from its own isolate
// (platform/notification_capture.dart). Both go through [fireDueAlerts],
// whose database claim makes "once per threshold per period" hold no matter
// which of them notices first.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/serial_queue.dart';
import '../../platform/alerts.dart';
import 'app_providers.dart';

final _alertQueue = SerialQueue();

/// Start once, from Fuata's build (watched, like bannerSyncProvider).
final alertSyncProvider = Provider<void>((ref) {
  final units = ref.watch(unitsProvider);
  final transactions = ref.watch(transactionsProvider);
  final limits = ref.watch(limitsProvider);
  final settings = ref.watch(settingsProvider);

  // Still loading: evaluating against half the data could announce a
  // crossing that isn't real. Wait for everything.
  if (units.value == null ||
      transactions.value == null ||
      limits.value == null ||
      settings.value == null) {
    return;
  }

  final unitRepo = ref.read(unitRepositoryProvider);
  final txRepo = ref.read(transactionRepositoryProvider);
  final limitRepo = ref.read(limitRepositoryProvider);
  final settingsRepo = ref.read(settingsRepositoryProvider);
  final log = ref.read(alertLogRepositoryProvider);

  // Serialised so two quick changes can't run two evaluations at once in
  // this isolate. An alert failure must never surface to the person.
  _alertQueue.run(() async {
    try {
      await fireDueAlerts(
        units: unitRepo,
        transactions: txRepo,
        limits: limitRepo,
        settings: settingsRepo,
        log: log,
      );
    } catch (e) {
      debugPrint('[alerts] failed: ${e.runtimeType}');
    }
  });
});
