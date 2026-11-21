// ---------------------------------------------------------------------------
// Listener status (issue #36).
//
// Android has no API that says "your notification listener is bound right
// now". design.md 5.1 documents a phone (MIUI) where the grant reads as on
// but the system never binds the service, so notifications are silently
// dropped. What Android does give the service is two callbacks —
// onListenerConnected / onListenerDisconnected — which the native side
// records as timestamps (CaptureStore.kt). This file turns those raw times
// into one of four states. It is a pure function: no Flutter, no platform
// channel, so every branch is unit-tested off-device.
//
// It is a best guess, not proof. Callers must say "looks inactive", never
// "broken", and must not imply that fixing it guarantees capture.
// ---------------------------------------------------------------------------

/// How long after a grant, a boot or a disconnect Fuata waits for Android to
/// (re)bind the listener before calling it stalled.
///
/// A starting value only: design/#36 open question 1 asks for it to be
/// measured on the MIUI phone (30 s? 2 min?). One constant, so changing it
/// is a one-line edit.
const Duration kListenerGrace = Duration(minutes: 2);

enum ListenerStatus {
  /// Notification access is not granted.
  off,

  /// Granted, and Android bound the listener after the grant / boot and has
  /// not unbound it since.
  active,

  /// Granted, but the listener has not (re)connected and the grace period
  /// has run out: it never bound, or it was unbound and did not come back.
  stalled,

  /// Granted, but too soon to tell (just granted, just booted, or just
  /// disconnected). Do not alarm.
  unknown,
}

/// Works out the [ListenerStatus].
///
/// * [granted]        — the notification-access grant is on.
/// * [connectedAt]    — last onListenerConnected, or null if never recorded.
/// * [disconnectedAt] — last onListenerDisconnected, or null.
/// * [grantedAt]      — when the grant was first seen on, or null if unknown.
/// * [bootAt]         — when the phone last booted. A connect recorded before
///                      it belongs to a previous boot.
/// * [now]            — injected so the grace boundary is testable.
ListenerStatus computeListenerStatus({
  required bool granted,
  required DateTime? connectedAt,
  required DateTime? disconnectedAt,
  required DateTime? grantedAt,
  required DateTime bootAt,
  required DateTime now,
  Duration grace = kListenerGrace,
}) {
  if (!granted) return ListenerStatus.off;

  // Only a connect from this boot, and at/after the grant, counts.
  final reference = (grantedAt != null && grantedAt.isAfter(bootAt))
      ? grantedAt
      : bootAt;
  final connectedSinceReference =
      connectedAt != null && !connectedAt.isBefore(reference);

  // A disconnect newer than the last connect means it was unbound and has
  // not come back. Equal times count as connected (reconnected at once).
  final disconnected = disconnectedAt;
  final disconnectedSinceConnect =
      disconnected != null &&
      (connectedAt == null || disconnected.isAfter(connectedAt));

  if (connectedSinceReference && !disconnectedSinceConnect) {
    return ListenerStatus.active;
  }

  // Not bound as far as we can tell. Give Android time before alarming: the
  // clock starts at the grant/boot, or at the disconnect if that is newer
  // (a rebind has just been requested and takes a moment).
  var anchor = reference;
  if (disconnected != null &&
      disconnectedSinceConnect &&
      disconnected.isAfter(anchor)) {
    anchor = disconnected;
  }
  final waited = now.difference(anchor);
  return waited < grace ? ListenerStatus.unknown : ListenerStatus.stalled;
}
