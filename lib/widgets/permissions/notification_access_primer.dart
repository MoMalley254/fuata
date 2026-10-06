import 'package:flutter/material.dart';

import '../personalization/permission_primer_dialog.dart';

/// F17: the dialog shown before sending someone to Android's
/// notification-access screen. The wording matches what Android actually
/// says there (the "read all notifications" warning is shown for every
/// app with this permission) and covers the sideloaded-build
/// "restricted settings" step.
///
/// Call this from both places that can trigger the jump — the onboarding
/// auto-catch hand-off and Settings > Auto-catch > Turn on access — so the
/// two are the same moment.
Future<bool> showNotificationAccessPrimer(BuildContext context) async {
  final ok = await showPermissionPrimerDialog(
    context: context,
    title: "Before we jump to Android's settings 👋",
    body:
        'To catch your payments, Fuata needs notification access. When you '
        'tap "Take me there", Android opens a list of apps. Find Fuata and '
        'switch it on.',
    bullets: const [
      'It only looks at the apps you choose.',
      "It never sends anything anywhere. There's no internet permission in this app.",
      'You can switch it off any time, in Fuata or in Android settings.',
    ],
    androidWarning:
        'Heads-up: Android is going to sound alarmed. It will warn that '
        'Fuata can "read all notifications". Android shows that message for '
        'every app with this permission, on purpose, because the permission '
        'is powerful. What Fuata actually does is in the list above.',
    restrictedSettingsNote:
        "If the switch is greyed out, open Fuata's App info, tap ⋮ and choose "
        '"Allow restricted settings", then try again.',
    ifYoudRatherNot:
        "If you'd rather not: that's fine. Fuata works without it. You'd "
        'add payments by hand or share a message to Fuata.',
  );
  return ok == true;
}
