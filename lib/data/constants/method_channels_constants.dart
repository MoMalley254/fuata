const String shareIntakeMethodName = 'fuata/share_intake';

// Issue #22. `capture` is the UI isolate <-> native channel (allow-list,
// notification-access status, installed apps, "captures changed" ping);
// `capture_bg` is the background isolate <-> native channel the listener
// service uses to hand a notification to Dart.
const String captureMethodName = 'fuata/capture';
const String captureBackgroundMethodName = 'fuata/capture_bg';