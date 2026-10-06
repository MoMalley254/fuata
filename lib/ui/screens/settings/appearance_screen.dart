import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/settings.dart';
import '../../../widgets/app_chips.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';


/// Appearance (issue #79, finding F3): light / dark / follow system.
///
/// The accent colour is on the Profile screen, next to the name and
/// avatar — both are "how the app is mine". This screen is only the
/// theme, which is a choice about the phone, not about the person.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              title: 'Theme',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: AppThemeMode.values.map((mode) {
                    return AppChoiceChip(
                      label: mode.label,
                      leading: Icon(
                        mode.icon,
                        size: 16,
                        color: settings.themeMode == mode
                            ? c.primary
                            : c.onSurfaceVariant,
                      ),
                      selected: settings.themeMode == mode,
                      onTap: () => update((s) => s.copyWith(themeMode: mode)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}