// ---------------------------------------------------------------------------
// The OS-level half of "Hide in app switcher" (issue #84, finding F20).
//
// While FLAG_SECURE is set, Android blanks Fuata in the app switcher and
// refuses to take screenshots or screen recordings. The setting in
// Settings > Privacy & data stores the person's choice; this is what
// actually tells Android about it.
//
// Nothing in here logs.
// ---------------------------------------------------------------------------
import 'package:flutter/services.dart';
import 'package:fuata/data/constants/method_channels_constants.dart';

final _channel = MethodChannel(privacyMethodName);

/// Set or clear FLAG_SECURE on the current window. Idempotent from the
/// caller's point of view — the native side no-ops a re-send of the same
/// value.
///
/// A no-op on non-Android and in widget tests (no native side), so callers
/// don't have to guard.
Future<void> applySecure(bool secure) async {
  try {
    await _channel.invokeMethod<void>('setSecure', secure);
  } on MissingPluginException {
    // Widget tests / non-Android: no native side.
  } on PlatformException {
    // A window that fails to accept the flag is not the app's problem;
    // the next push (or the next start) will retry.
  }
}