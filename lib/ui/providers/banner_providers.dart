// ---------------------------------------------------------------------------
// The ongoing banner's data-driven re-post (issue #16, US-05).
//
// HomeState already recomputes on every units/transactions/limits change
// (app_providers.dart), and settings change on every write — so watching
// both is enough to re-post whenever the numbers or the options move.
// What this deliberately does *not* handle: a capture written by the
// notification listener's background isolate. That path re-posts from
// its own isolate (platform/notification_capture.dart), because the UI
// isolate isn't running to notice.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/banner_content.dart';
import '../../platform/banner.dart';
import 'app_providers.dart';

/// Start once, from Fuata's initState. Never read the value — the side
/// effect *is* the provider.
final bannerSyncProvider = Provider<void>((ref) {
  final home = ref.watch(homeStateProvider).value;
  final settings = ref.watch(currentSettingsProvider);

  // Still loading: don't cancel a banner the background isolate just
  // posted, and don't post a stale one. Wait for the first real value.
  if (home == null) return;

  if (!settings.bannerEnabled) {
    BannerPlatform.instance.cancel();
    return;
  }

  // #30: the outing drives the banner only when its own `bannerEnabled`
  // is true. `bannerEnabled` on the outing is a *per-outing* toggle,
  // distinct from the app-wide `AppSettings.bannerEnabled` above — the
  // app-wide switch is a hard gate, the outing switch is a soft one.
  final outing = home.activeOuting;
  final useOuting = outing != null && outing.bannerEnabled;

  final content = BannerContent.build(
    status: home.status,
    spentToday: home.spentToday,
    dailyLimit: home.dailyLimit,
    units: home.units,
    balanceByUnit: home.balanceByUnit,
    headline: settings.bannerHeadline,
    unitsMode: settings.bannerUnitsMode,
    selectedUnitIds: settings.bannerUnitIds,
    showProgress: settings.bannerShowProgress,
    showQuickAdd: settings.bannerShowQuickAdd,
    redacted: false,
    activeOuting: useOuting ? outing : null,
    outingSpentMinor: useOuting ? home.outingSpent : 0,
    outingStatus: useOuting ? home.outingStatus : null,
  );

  BannerPlatform.instance.show(
    content,
    redactOnLockScreen: settings.redactedLockScreenBanner,
  );
});