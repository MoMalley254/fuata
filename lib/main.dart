import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:fuata/platform/notification_capture.dart';
import 'package:fuata/platform/share_intake.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/providers/capture_providers.dart';
import 'package:fuata/ui/screens/root_shell.dart';
import 'package:fuata/ui/theme/app_theme.dart';

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

  runApp(const ProviderScope(child: Fuata()));
}

class Fuata extends ConsumerStatefulWidget {
  const Fuata({super.key});

  @override
  ConsumerState<Fuata> createState() => _FuataState();
}

class _FuataState extends ConsumerState<Fuata> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Starts the share subscription for the app's lifetime.
    ref.read(shareIntakeListenerProvider);
    // Issue #22: mirror the allow-list to the native listener, and hear
    // about captures the background isolate wrote.
    ref.read(allowListSyncProvider);
    ref.read(captureRefreshProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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