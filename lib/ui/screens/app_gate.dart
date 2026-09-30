import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'onboarding_screen.dart';
import 'root_shell.dart';

/// What the app opens to (issue #7): onboarding on the very first launch,
/// the normal tabs ever after.
///
/// It waits for the first settings read before choosing. Without that wait,
/// [currentSettingsProvider] would hand back defaults (onboarding not done)
/// for a moment and flash onboarding at someone who finished it long ago.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(settingsProvider)
        .when(
      // A blank themed screen for the instant it takes to read them.
      loading: () => const Scaffold(),
      // Never trap someone outside their own money over a settings error.
      error: (error, stack) => const RootShell(),
      data: (settings) => settings.onboardingComplete
          ? const RootShell()
          : const OnboardingScreen(),
    );
  }
}