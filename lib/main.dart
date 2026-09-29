import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:fuata/platform/banner.dart';
import 'package:fuata/platform/notification_capture.dart';
import 'package:fuata/platform/share_intake.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/providers/banner_providers.dart';
import 'package:fuata/ui/providers/capture_providers.dart';
import 'package:fuata/ui/screens/root_shell.dart';
import 'package:fuata/ui/theme/app_theme.dart';
import 'package:fuata/widgets/sheets/add_transaction_sheet.dart';

import 'domain/models/settings.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Issue #22: registers the background isolate entry point so Android
  // can find it again later, even when the app process has been killed
  // and the notification listener service starts it cold.
  await registerCaptureCallback();

  // Issue #21: receive text shared from other apps (ACTION_SEND), now and
  // on every cold start launched from a share sheet.
  await initShareIntake();

  // Issue #16: create both notification channels and register the tap
  // handler *before* runApp, so a cold start from a banner tap has
  // somewhere to land.
  await BannerPlatform.instance.init();

  runApp(const ProviderScope(child: Fuata()));
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
    // Starts the share subscription for the app's lifetime.
    ref.read(shareIntakeListenerProvider);
    // Issue #22: mirror the allow-list to the native listener, and hear
    // about captures the background isolate wrote.
    ref.read(allowListSyncProvider);
    ref.read(captureRefreshProvider);
    _bannerSub = BannerPlatform.instance.actions.listen(_onBannerAction);

    // Cold start from a banner tap or its + Add — the callback fired
    // before initState could subscribe.
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

  void _onBannerAction(BannerAction action) {
    switch (action) {
      case BannerAction.open:
      // The app is already coming to the front; nothing to route.
        break;
      case BannerAction.quickAdd:
      // US-07: straight into the add sheet, no menus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) showAddTransactionSheet(ctx);
        });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Belt and braces for the native "captures changed" ping: whatever the
    // background isolate wrote while we were away, re-query on return.
    if (state == AppLifecycleState.resumed) {
      final db = ref.read(appDatabaseProvider);
      db.markTablesUpdated([db.transactions, db.unparsedCaptures]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Issue #16: keep the ongoing banner in step with the data. Watch,
    // not read — a bare `ref.read` in initState instantiates the
    // provider once but never re-runs its body when settings or
    // homeState change, so the banner never re-posts. Watching it
    // subscribes, which is what keeps it firing.
    ref.watch(bannerSyncProvider);

    final settings = ref.watch(currentSettingsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode.flutterThemeMode,
      theme: AppTheme.light(accent: settings.accent),
      darkTheme: AppTheme.dark(accent: settings.accent),
      home: const RootShell(),
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      builder: FlutterSmartDialog.init(),
      navigatorObservers: [FlutterSmartDialog.observer],
    );
  }
}