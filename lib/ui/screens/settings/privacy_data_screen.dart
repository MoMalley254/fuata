import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/widgets/dialogs/show_erase_everything_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/settings.dart';
import '../../../routing/routes.dart';
import '../../../widgets/personalization/privayc_card.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_spacing.dart';

/// Privacy & data (issue #79, finding F3): the reassuring panel, the two
/// privacy toggles, Back up & restore, and the (not yet wired) Erase
/// everything. Its own screen now — the last card of the old Me list was
/// the one thing on it worth a title of its own.
class PrivacyDataScreen extends ConsumerWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            PrivacyCard(
              settings: settings,
              onChanged: update,
              onOpenBackup: () => context.push(Routes.backupPath),
              onErase: () => eraseAllData(ref),
              onOpenScheduledExport: () => context.push(Routes.scheduledExportPath),
            ),

          ],
        ),
      ),
    );
  }
}