import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The SQLCipher key for the on-device database.
///
/// Generated once on first run and stored behind Android Keystore (via
/// flutter_secure_storage's `encryptedSharedPreferences` on Android 6+,
/// which uses a Keystore-backed master key). The key never leaves the
/// device and is never derived from anything the person can be coerced
/// into typing.
class DbKey {
  DbKey._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static const _keyName = 'fuata.db_key.v1';

  static Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return existing;

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final key = hex;
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  /// Wipes the key. Used by "Erase everything" — after this, the DB file
  /// is unrecoverable garbage, which is the point.
  static Future<void> destroy() => _storage.delete(key: _keyName);
}