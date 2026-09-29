import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:fuata/platform/listener_spike.dart';
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
  // Issue #18 spike only: registers the background isolate entry point so
  // Android can find it again later even if the app process has been
  // killed. Remove this call when #22 replaces the spike.
  await registerListenerSpikeCallback();

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

class _FuataState extends ConsumerState<Fuata> {
  @override
  void initState() {
    super.initState();
    // Starts the share subscription for the app's lifetime.
    ref.read(shareIntakeListenerProvider);
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
