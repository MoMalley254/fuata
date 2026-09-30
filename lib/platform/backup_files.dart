// ---------------------------------------------------------------------------
// Saving and opening backup files (issue #24). A thin wrapper over the
// `fuata/backup_files` channel (android/.../BackupFilesChannel.kt), behind
// an interface so the screen can be tested without a platform.
// ---------------------------------------------------------------------------

import 'package:flutter/services.dart';

import '../data/constants/method_channels_constants.dart';

/// A file problem with a message fit to show the person.
class BackupFileException implements Exception {
  final String message;
  const BackupFileException(this.message);

  @override
  String toString() => message;
}

abstract class BackupFilePlatform {
  /// Asks the person where to save, then writes [content] there.
  /// False if they backed out.
  Future<bool> saveText({
    required String suggestedName,
    required String content,
  });

  /// Asks the person to pick a file and returns its text. Null if they
  /// backed out.
  Future<String?> pickText();
}

class AndroidBackupFiles implements BackupFilePlatform {
  AndroidBackupFiles() : _channel = const MethodChannel(backupFilesMethodName);
  final MethodChannel _channel;

  @override
  Future<bool> saveText({
    required String suggestedName,
    required String content,
  }) async {
    try {
      final saved = await _channel.invokeMethod<bool>('saveText', {
        'name': suggestedName,
        'content': content,
      });
      return saved ?? false;
    } on PlatformException catch (e) {
      throw BackupFileException(switch (e.code) {
        'busy' => 'A file window is already open.',
        _ => "Couldn't save the file there. Try another location.",
      });
    } on MissingPluginException {
      throw const BackupFileException(
        "This device can't save files from Fuata.",
      );
    }
  }

  @override
  Future<String?> pickText() async {
    try {
      return await _channel.invokeMethod<String>('pickText');
    } on PlatformException catch (e) {
      throw BackupFileException(switch (e.code) {
        'busy' => 'A file window is already open.',
        'too_large' => "That file is too big to be a Fuata backup.",
        _ => "Couldn't read that file. Try another one.",
      });
    } on MissingPluginException {
      throw const BackupFileException(
        "This device can't open files from Fuata.",
      );
    }
  }
}
