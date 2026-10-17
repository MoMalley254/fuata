// ---------------------------------------------------------------------------
// The backup passphrase, cached behind Android Keystore (issue #35).
//
// A scheduled export runs unattended: it cannot prompt for a passphrase at
// 3am. Caching the passphrase (encrypted by the Keystore) is what makes
// the schedule work; it's the same trade the database key already makes
// (ADR-010's plan for SQLCipher). A backup restored onto a different phone
// cannot use the cached passphrase — Keystore is device-bound — so restore
// prompts, and this store is the cache, not the source of truth.
// ---------------------------------------------------------------------------
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupPassphraseStore {
  BackupPassphraseStore._();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());
  static const _key = 'fuata.scheduled_export.passphrase.v1';

  static Future<String?> read() => _storage.read(key: _key);

  static Future<void> write(String passphrase) =>
      _storage.write(key: _key, value: passphrase);

  static Future<void> clear() => _storage.delete(key: _key);

  /// True when a passphrase is cached. Cheap; safe to call from a build
  /// method's provider init.
  static Future<bool> hasValue() async => (await read()) != null;
}