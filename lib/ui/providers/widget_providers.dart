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

import '../../domain/logic/ledger.dart';
import '../../domain/logic/widget_content.dart';
import '../../domain/models/limit_rule.dart';
import '../../platform/widget_bridge.dart';
import 'app_providers.dart';

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>((ref) {
  return AndroidHomeWidgetBridge();
});

/// Watched from Fuata's build, like bannerSyncProvider and
/// alertSyncProvider — the side effect is the point.
///
/// Deliberately NOT gated on bannerEnabled: the widget and the banner
/// have independent lifecycles. Someone who turned the banner off can
/// still want a home-screen glance.
final widgetSyncProvider = Provider<void>((ref) {
  final units = ref.watch(unitsProvider);
  final transactions = ref.watch(transactionsProvider);
  final limits = ref.watch(limitsProvider);
  final settings = ref.watch(settingsProvider);
  final bridge = ref.watch(homeWidgetBridgeProvider);

  // Wait for every stream: building from half-loaded data would push a
  // widget that disagrees with what the person sees in the app.
  if (units.value == null ||
      transactions.value == null ||
      limits.value == null ||
      settings.value == null) {
    return;
  }

  final s = settings.value!;
  final unitList = units.value!;
  final txList = transactions.value!;

  // A synchronous build rather than the async loader: every input is
  // already in hand, and the async version would open a second DB read
  // just to re-derive what the providers already hold.
  final now = DateTime.now();
  final (start, end) = Ledger.todayRange(now);
  final spentToday = Ledger.spentInPeriod(txList, start, end);

  LimitRule? daily;
  for (final l in limits.value!) {
    if (l.enabled &&
        l.scope == LimitScope.overall &&
        l.period == LimitPeriod.day) {
      daily = l;
      break;
    }
  }

  final currency = unitList.isNotEmpty
      ? unitList.first.currencyCode
      : 'KES';
  final balanceByUnit = {
    for (final u in unitList) u.id: Ledger.balanceOf(u, txList),
  };

  bridge.push(
    WidgetSnapshot.build(
      status: Ledger.statusFor(daily, spentToday),
      spentToday: spentToday,
      dailyLimit: daily,
      currencyCode: currency,
      headline: s.widgetHeadline,
      unitsMode: s.widgetUnitsMode,
      selectedUnitIds: s.widgetUnitIds,
      showProgress: s.widgetShowProgress,
      showSplit: s.widgetShowSplit,
      variant: s.widgetVariant,
      units: unitList,
      balanceByUnit: balanceByUnit,
    ),
  );
});