import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/data/constants/global_variables.dart';
import 'package:fuata/widgets/personalization/action_row.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/logic/diagnostics.dart';
import '../ui/providers/app_providers.dart';
import '../ui/providers/capture_providers.dart';

class HelpAndDiagnosticsWidget extends ConsumerWidget {
  const HelpAndDiagnosticsWidget({super.key});

  Future<void> _emailDiagnostics(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    // 1. Gather and copy to clipboard as a fallback (in case the email client truncates long mailto links)
    try {
      await copyDiagnosticsToClipboard(
        units: ref.read(unitRepositoryProvider),
        transactions: ref.read(transactionRepositoryProvider),
        templates: ref.read(templateRepositoryProvider),
        outings: ref.read(outingRepositoryProvider),
        sources: ref.read(captureSourceRepositoryProvider),
        captures: ref.read(captureRepositoryProvider),
        limits: ref.read(limitRepositoryProvider),
        categories: ref.read(categoryRepositoryProvider),
        settings: ref.read(settingsRepositoryProvider),
        appVersion: '1.0.0+2', // Match pubspec.yaml version
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to prepare diagnostics.')),
      );
      return;
    }

    // 2. Build the mailto URI
    const subject = 'Fuata Diagnostics Report';

    // We fetch it again to get the string for the body
    final data = await gatherDiagnostics(
      units: ref.read(unitRepositoryProvider),
      transactions: ref.read(transactionRepositoryProvider),
      templates: ref.read(templateRepositoryProvider),
      outings: ref.read(outingRepositoryProvider),
      sources: ref.read(captureSourceRepositoryProvider),
      captures: ref.read(captureRepositoryProvider),
      limits: ref.read(limitRepositoryProvider),
      categories: ref.read(categoryRepositoryProvider),
      settings: ref.read(settingsRepositoryProvider),
    );

    final body =
        '${data.toString()}\n\n---\nPlease describe the issue you are experiencing below this line:\n';

    final uri = Uri.parse(
      'mailto:$supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    // 3. Launch the email client
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Diagnostics copied to clipboard and email opened.'),
          ),
        );
      }
    } else {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email client. Diagnostics remain in your clipboard.',
            ),
          ),
        );
        // Fallback: explicitly tell them it's in the clipboard
        messenger.showSnackBar(
          const SnackBar(content: Text('Diagnostics copied to clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionRow(
      icon: Icons.bug_report_outlined,
      title: 'Email diagnostics',
      subtitle: 'Shares anonymized app state for troubleshooting',
      onTap: () => _emailDiagnostics(context, ref),
    );
  }
}
