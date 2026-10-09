// ---------------------------------------------------------------------------
// Loading what the ongoing banner needs (issue #16). Depends only on
// repository interfaces, so the same function runs in the UI isolate
// (via banner_providers.dart) and in the notification listener's
// background isolate (via platform/notification_capture.dart) — the
// banner a person sees can never disagree with what the parser wrote.
// ---------------------------------------------------------------------------

import '../models/limit_rule.dart';
import '../repositories/repositories.dart';
import 'banner_content.dart';
import 'ledger.dart';

/// Returns the content the banner should show, or null when the banner
/// is switched off in settings (in which case the caller should cancel
/// any stale one).
///
/// [now] is injectable so tests can pin "today"; production callers leave
/// it out and get [DateTime.now].
Future<BannerContent?> loadBannerContent({
  required UnitRepository units,
  required TransactionRepository transactions,
  required LimitRepository limits,
  required SettingsRepository settings,
  DateTime Function()? now,
}) async {
  final clock = now ?? DateTime.now;

  final s = await settings.watchSettings().first;
  if (!s.bannerEnabled) return null;

  final unitList = await units.watchUnits().first;
  final txList = await transactions.watchTransactions().first;
  final limitList = await limits.watchLimits().first;

  final (start, end) = Ledger.todayRange(clock());
  final spentToday = Ledger.spentInPeriod(txList, start, end);

  final dailyLimit = limitList
      .where((l) =>
  l.scope == LimitScope.overall &&
      l.period == LimitPeriod.day &&
      l.enabled)
      .firstOrNull;

  final balanceByUnit = {
    for (final u in unitList) u.id: Ledger.balanceOf(u, txList),
  };

  return BannerContent.build(
    status: Ledger.statusFor(dailyLimit, spentToday),
    spentToday: spentToday,
    dailyLimit: dailyLimit,
    units: unitList,
    balanceByUnit: balanceByUnit,
    headline: s.bannerHeadline,
    unitsMode: s.bannerUnitsMode,
    selectedUnitIds: s.bannerUnitIds,
    showProgress: s.bannerShowProgress,
    showQuickAdd: s.bannerShowQuickAdd,
    // Never pre-redacted here: the *real* banner defers redaction to
    // Android's lock-screen visibility (see BannerPlatform.show). The
    // setup screen's preview uses `redacted: true` on its own to mock
    // what the lock screen version looks like.
    redacted: false,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}