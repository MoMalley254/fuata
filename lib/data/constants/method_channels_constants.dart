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