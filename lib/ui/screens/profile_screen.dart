import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/settings.dart';
import '../../widgets/personalization/profile_block.dart';
import '../providers/app_providers.dart';
import '../theme/app_spacing.dart';

/// Your own name and colour (issue #79, finding F3): split out of the old
/// Me screen so it can be reached from Today's avatar instead of being the
/// first card of an app-settings list.
///
/// The body is the existing [ProfileBlock], unchanged, so the fields and
/// the "custom colour picker is coming later" note are the ones people
/// may already have seen. The block's own heading was dropped — a card
/// titled "Profile" under a screen titled "Profile" is just the same word
/// twice (see [SectionCard.title] being optional).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            ProfileBlock(settings: settings, onChanged: update),
          ],
        ),
      ),
    );
  }
}