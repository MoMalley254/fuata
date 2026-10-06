import 'package:flutter/material.dart';

import '../personalization/permission_primer_dialog.dart';

/// F18: shown the first time any app is switched on, and again when a
/// messages app is switched on. A messages app is a bigger decision than
/// it looks, because Android delivers every notification from it to
/// Fuata: chats, one-time codes, delivery updates. The dialog says so
/// plainly, and says what Fuata actually keeps.
Future<bool> showAppsToWatchExplainer(
  BuildContext context, {
  required String appLabel,
  required bool isMessagesApp,
}) async {
  final ok = await showPermissionPrimerDialog(
    context: context,
    title: 'Watching "$appLabel"',
    body:
        'Fuata will see the notifications this app shows, including ones '
        "that aren't about money. It only keeps the ones it can read as "
        'payments, using the rules you teach it.',
    bullets: const [
      'Tip: pick your messages app and your bank or M-PESA app. You don\'t '
          'need anything else.',
      'You can turn any app off here at any time.',
    ],
    ifYoudRatherNot: isMessagesApp
        ? 'Android delivers every notification from a messages app, so Fuata '
              'will see chats and one-time codes too. It drops them the moment '
              'they arrive — they are never stored.'
        : null,
    primaryLabel: 'Got it',
    secondaryLabel: 'Cancel',
  );
  return ok == true;
}
