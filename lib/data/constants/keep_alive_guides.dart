// ---------------------------------------------------------------------------
// Manufacturer keep-alive guides (issue #36).
//
// Some phones kill background services to save battery, which stops
// Fuata's notification listener (requirements.md §8, "Manufacturer battery
// killers"). Each entry here is plain text the person follows by hand.
//
// Rules for adding one:
//  * Only add a manufacturer once someone has checked the steps on a real
//    device. Vendor settings move between OS versions, so record that
//    version in [KeepAliveGuide.checkedOn]; until then say so (null).
//  * A deep link is only for a PUBLIC Android settings screen ([SettingsTarget]).
//    Vendor pages (MIUI Autostart, etc.) have no public intent, so those
//    steps stay plain text.
//  * Static content: no new permissions.
// ---------------------------------------------------------------------------

/// Public system screens the guide can open (see CaptureChannel.kt,
/// `openSystemSettings`). The [name] is the string sent over the channel.
enum SettingsTarget { batteryOptimization, appInfo, notificationAccess }

class KeepAliveStep {
  final String text;

  /// Optional button that opens a public settings screen for this step.
  final SettingsTarget? target;
  final String? targetLabel;

  const KeepAliveStep(this.text, {this.target, this.targetLabel});
}

class KeepAliveGuide {
  /// Shown as the card title, e.g. "Xiaomi, Redmi and Poco".
  final String name;
  final String intro;
  final List<KeepAliveStep> steps;

  /// The OS version the steps were last checked on; null = not recorded yet.
  final String? checkedOn;

  /// True for the generic fallback rather than a manufacturer entry.
  final bool isFallback;

  const KeepAliveGuide({
    required this.name,
    required this.intro,
    required this.steps,
    this.checkedOn,
    this.isFallback = false,
  });
}

/// Works on any Android phone. Also what an unmatched manufacturer gets.
const KeepAliveGuide genericKeepAliveGuide = KeepAliveGuide(
  name: 'Keep Fuata running',
  intro:
      'Some phones stop apps that are not open to save battery. These two '
      'settings give Fuata the best chance of hearing about your payments.',
  isFallback: true,
  steps: [
    KeepAliveStep(
      'Let Fuata run without battery limits. Find Fuata in the list and '
      'choose “Don’t optimise” (the wording differs by phone).',
      target: SettingsTarget.batteryOptimization,
      targetLabel: 'Open battery optimisation',
    ),
    KeepAliveStep(
      'In Fuata’s App info, open Battery (or “App battery usage”) and allow '
      'background activity / choose “Unrestricted”.',
      target: SettingsTarget.appInfo,
      targetLabel: 'Open Fuata’s App info',
    ),
  ],
);

/// The only manufacturer confirmed so far (design.md 5.1): Autostart on,
/// battery unrestricted, app locked in recents. Redmi and Poco phones
/// report their maker as Xiaomi.
const KeepAliveGuide xiaomiKeepAliveGuide = KeepAliveGuide(
  name: 'Xiaomi, Redmi and Poco',
  intro:
      'Xiaomi’s system often stops Fuata’s listener in the background. '
      'Do all three, then come back and check Auto-catch.',
  // Not recorded yet: fill in the MIUI/HyperOS version it was checked on.
  checkedOn: null,
  steps: [
    KeepAliveStep(
      'Turn on Autostart for Fuata. It is usually under Settings › Apps › '
      'Manage apps › Fuata.',
      target: SettingsTarget.appInfo,
      targetLabel: 'Open Fuata’s App info',
    ),
    KeepAliveStep(
      'Remove the battery limit: in Fuata’s App info, open Battery saver (or '
      '“Battery”) and choose No restrictions.',
    ),
    KeepAliveStep(
      'Lock Fuata in the recent-apps screen: open recents, pull Fuata’s card '
      'down (or tap its menu) and choose the lock.',
    ),
  ],
);

/// Keyed by `Build.MANUFACTURER`, lower-cased. Add other makers here only
/// after their steps are checked on a real device.
const Map<String, KeepAliveGuide> keepAliveGuides = {
  'xiaomi': xiaomiKeepAliveGuide,
  // Some builds report the sub-brand instead.
  'redmi': xiaomiKeepAliveGuide,
  'poco': xiaomiKeepAliveGuide,
};

/// The guide for [manufacturer] (any case, may be null), or the generic one.
KeepAliveGuide keepAliveGuideFor(String? manufacturer) {
  final key = manufacturer?.trim().toLowerCase();
  if (key == null || key.isEmpty) return genericKeepAliveGuide;
  return keepAliveGuides[key] ?? genericKeepAliveGuide;
}
