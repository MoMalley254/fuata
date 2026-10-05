const dedupeWindowDuration = Duration(minutes: 2);

/// How long a "couldn't read this" message is kept before auto-purge
/// (US-11, issue #74). Long enough to sit down and teach Fuata the
/// shape; short enough that a forgotten list can't accumulate.
const unparsedCaptureRetention = Duration(days: 14);

/// Upper bound on how many unreadable messages are kept at once. The
/// oldest beyond this are dropped even inside the retention window — a
/// runaway loop (an app re-posting, a rule that never matches) must not
/// grow the table without bound.
const unparsedCaptureCap = 200;