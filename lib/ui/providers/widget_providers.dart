// ---------------------------------------------------------------------------
// Pushing the home-screen widget's snapshot on every data change (issue
// #29). Same shape as bannerSyncProvider: watch the data, act when it
// moves. The widget has no other automatic source of truth besides the
// launcher's 30-minute fallback, so this provider is what makes the
// widget *feel* live.
//
// Deliberately NOT gated on bannerEnabled: the widget and the banner
// have independent lifecycles. Someone who turned the banner off can
// still want a home-screen glance.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/widget_content.dart';
import '../../platform/widget_bridge.dart';
import 'app_providers.dart';

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>((ref) {
  return AndroidHomeWidgetBridge();
});

/// Watched from Fuata's build, like bannerSyncProvider and
/// alertSyncProvider — the side effect is the point.
final widgetSyncProvider = Provider<void>((ref) {
  final home = ref.watch(homeStateProvider).value;
  final bridge = ref.watch(homeWidgetBridgeProvider);

  // Still loading: the widget keeps whatever it last had rather than
  // flashing "—" for a frame on cold start.
  if (home == null) return;

  final currency = home.units.isNotEmpty
      ? home.units.first.currencyCode
      : 'KES';

  bridge.push(
    WidgetSnapshot.build(
      status: home.status,
      spentToday: home.spentToday,
      dailyLimit: home.dailyLimit,
      currencyCode: currency,
    ),
  );
});