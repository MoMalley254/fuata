const String shareIntakeMethodName = 'fuata/share_intake';

// Issue #22. `capture` is the UI isolate <-> native channel (allow-list,
// notification-access status, installed apps, "captures changed" ping);
// `capture_bg` is the background isolate <-> native channel the listener
// service uses to hand a notification to Dart.
const String captureMethodName = 'fuata/capture';
const String captureBackgroundMethodName = 'fuata/capture_bg';

// Issue #24. Save / open a backup file through Android's system file
// picker (Storage Access Framework): no storage permission, and the
// person chooses the location (US-15).
const String backupFilesMethodName = 'fuata/backup_files';

// Issue #29. The home-screen widget's one-way data channel: Dart pushes
// a small snapshot; the native AppWidgetProvider reads it and renders
// RemoteViews. Nothing comes back over the channel — a tap on the widget
// just launches the app.
const String homeWidgetMethodName = 'fuata/home_widget';

// Issue #84. Sets/clears Android's FLAG_SECURE on the window: blank card
// in the app switcher, no screenshots. One method — setSecure(bool).
const String privacyMethodName = 'fuata/privacy';