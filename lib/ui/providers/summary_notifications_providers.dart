// ---------------------------------------------------------------------------
// Keeping the scheduled summary notifications in step with the data (#31).
//
// Same shape as bannerSyncProvider and alertSyncProvider: watch everything
// the schedule depends on, act when it moves. Called from main.dart's build,
// so the reschedule happens on cold start and on every setting / data change.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/summary.dart';
import '../../domain/models/transaction.dart';
import '../../platform/summary_notifications.dart';
import 'app_providers.dart';

/// Watched once, from `Fuata`'s build. Never read the value — the
/// side-effect *is* the provider.
final summaryNotificationSyncProvider = Provider<void>((ref) {
  // Midnight rolls "today", "this week" and "this month" over, so the
  // bodies all need rebuilding. Same ticker the rest of the app uses.
  ref.watch(midnightTickProvider);
  final units = ref.watch(unitsProvider);
  final transactions = ref.watch(transactionsProvider);
  final settings = ref.watch(currentSettingsProvider);

  if (!settings.summaryNotificationsEnabled) {
    SummaryNotificationScheduler.instance.cancelAll();
    return;
  }

  final u = units.value;
  final t = transactions.value;
  // Still loading: don't cancel a pending notification the background
  // isolate just rescheduled, and don't rebuild one from half the data.
  if (u == null || t == null) return;

  final currency = u.isNotEmpty ? u.first.currencyCode : 'KES';
  // Same multi-currency rule the Summary screen uses: transactions on a
  // unit in another currency are excluded, not added in as if they were
  // the same money (testing.md T-13).
  final currencyByUnit = {for (final unit in u) unit.id: unit.currencyCode};
  bool include(MoneyTransaction tx) {
    final c = currencyByUnit[tx.unitId];
    return c == null || c == currency;
  }

  final now = DateTime.now();
  String body(SummaryPeriod p) => PeriodSummary.build(
    t,
    p,
    now,
    include: include,
  ).story(currency);

  SummaryNotificationScheduler.instance.scheduleAll(
    settings: settings,
    // Amounts are never masked here: the person explicitly asked for
    // these notifications, and the whole point is to see the numbers.
    // Lock-screen redaction is still honoured, via visibility below.
    texts: SummaryNotificationTexts(
      daily: body(SummaryPeriod.day),
      weekly: body(SummaryPeriod.week),
      monthly: body(SummaryPeriod.month),
    ),
    redactOnLockScreen: settings.redactedLockScreenBanner,
  );
});