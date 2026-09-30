import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/backup_files.dart';

/// The file picker/saver behind the Back up & restore screen (issue #24).
/// A provider so widget tests can override it with a fake and never touch
/// a platform channel.
final backupFilesProvider = Provider<BackupFilePlatform>((ref) {
  return AndroidBackupFiles();
});