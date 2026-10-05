import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:fuata/platform/banner.dart';
import 'package:fuata/platform/notification_capture.dart';
import 'package:fuata/platform/share_intake.dart';
import 'package:fuata/routing/app_router.dart';
import 'package:fuata/routing/routes.dart';
import 'package:fuata/ui/providers/alert_providers.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/providers/banner_providers.dart';
import 'package:fuata/ui/providers/capture_providers.dart';
import 'package:fuata/ui/theme/app_theme.dart';

import 'domain/models/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Issue #22: register the background isolate entry point so Android can
  // start it cold from a notification.
  await registerCaptureCallback();
  // Issue #21: share-sheet intake.
  await initShareIntake();

  // Issue #16 / #73: read the launch action *before* the router is built
  // so the router can pick the right initial location (—e.g. open /add
  // straight from a banner + Add on a cold start).
  final launchAction = await BannerPlatform.instance.initialActionFromLaunch();

  runApp(
    ProviderScope(
      overrides: [
        initialBannerActionProvider.overrideWithValue(launchAction),
      ],
      child: const Fuata(),
    ),
  );
}

class Fuata extends ConsumerStatefulWidget {
  const Fuata({super.key});

  @override
  ConsumerState<Fuata> createState() => _FuataState();
}

class _FuataState extends ConsumerState<Fuata> with WidgetsBindingObserver {
  StreamSubscription<BannerAction>? _bannerSub;

  @override
  void initState() {
    super.initState();
    ref.read(shareIntakeListenerProvider);
    ref.read(allowListSyncProvider);
    ref.read(captureRefreshProvider);
    _bannerSub = BannerPlatform.instance.actions.listen(_onBannerAction);

    // Cold start from a banner tap in the *warm* case (the app was
    // running, but nobody was listening yet).
    final pending = BannerPlatform.instance.consumePendingAction();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onBannerAction(pending);
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Warm-start banner actions. The cold-start case is handled by the
  /// router's `initialLocation`, so this only runs when the app is already
  /// alive.
  void _onBannerAction(BannerAction action) {
    final router = ref.read(routerProvider);
    switch (action) {
      case BannerAction.open:
      // The app is already coming to the front; land on Today.
        router.go(Routes.homePath);
      case BannerAction.quickAdd:
      // The redirect bounces this to /onboarding while setup is
      // unfinished; otherwise it opens the sheet.
        router.push(Routes.addPath);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final db = ref.read(appDatabaseProvider);
      db.markTablesUpdated([db.transactions, db.unparsedCaptures]);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bannerSyncProvider);
    ref.watch(alertSyncProvider);

    final settings = ref.watch(currentSettingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode.flutterThemeMode,
      theme: AppTheme.light(accent: settings.accent),
      darkTheme: AppTheme.dark(accent: settings.accent),
      routerConfig: router,
      builder: FlutterSmartDialog.init(),
      // rootNavigatorKey / rootScaffoldMessengerKey now come from the
      // router's config; importing them from main.dart is no longer
      // necessary anywhere else.
    );
  }
}