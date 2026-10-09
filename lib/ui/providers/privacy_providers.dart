// ---------------------------------------------------------------------------
// Mirroring "Hide in app switcher" to Android's FLAG_SECURE (issue #84).
//
// Same shape as bannerSyncProvider / alertSyncProvider: watch the setting,
// push it to the platform whenever it moves. The side effect is the point.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/privacy.dart';
import 'app_providers.dart';

/// Watched from Fuata's build.
///
/// Skips while the settings stream is still loading on purpose. `main()`
/// has already called `applySecure(true)` before the first frame, so the
/// initial Recents snapshot is blank; pushing here while settings are
/// still loading would flip the flag off before the person's real choice
/// arrived, which is the one moment a stale snapshot could get through.
final privacySyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  final secure = settings.value?.amountsHiddenInRecents;
  if (secure == null) return;
  applySecure(secure);
});