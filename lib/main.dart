import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/platform/listener_spike.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/screens/root_shell.dart';
import 'package:fuata/ui/theme/app_theme.dart';

import 'domain/models/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Issue #18 spike only: registers the background isolate entry point so
  // Android can find it again later even if the app process has been
  // killed. Remove this call when #22 replaces the spike.
  await registerListenerSpikeCallback();

  runApp(const ProviderScope(child: Fuata()));
}

/// Theme mode and accent colour now come from settings (#12) rather than
/// local widget state — `ThemeButton`'s old "TODO: Riverpod later" is
/// done, and that widget is retired in favour of Me → Appearance.
class Fuata extends ConsumerWidget {
  const Fuata({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode.flutterThemeMode,
      theme: AppTheme.light(accent: settings.accent),
      darkTheme: AppTheme.dark(accent: settings.accent),
      home: const RootShell(),
    );
  }
}

