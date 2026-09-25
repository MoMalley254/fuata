import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/screens/root_shell.dart';
import 'package:fuata/ui/theme/app_theme.dart';

import 'domain/models/settings.dart';

void main() {
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

