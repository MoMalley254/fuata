// ---------------------------------------------------------------------------
// Envelope encryption for Fuata backups (issue #35).
//
// AES-256-GCM, key derived from a passphrase with PBKDF2-HMAC-SHA256
// (100,000 iterations). Every file gets its own random 16-byte salt and
// 12-byte nonce, so two exports of the same data produce different
// ciphertexts and a stolen file is useless without the passphrase.
//
// The envelope wraps the plaintext JSON that BackupCodec already writes;
// nothing inside the file changes. Restore unwraps first, then hands the
// plaintext to BackupService.preview — the encryption is invisible to
// everything downstream.
// ---------------------------------------------------------------------------
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class BackupCrypto {
  BackupCrypto._();

  static const envelopeFormat = 'fuata-backup-encrypted';
  static const envelopeVersion = 1;
  static const _cipher = 'AES-256-GCM';
  static const _kdf = 'PBKDF2-HMAC-SHA256';
  static const _iterations = 100000;
  static const _saltBytes = 16;
  static const _minPassphraseLength = 8;

  /// True when [text] looks like an encrypted Fuata envelope. Never throws.
  static bool looksEncrypted(String text) {
    try {
      final root = jsonDecode(text);
      return root is Map<String, dynamic> && root['format'] == envelopeFormat;
    } catch (_) {
      return false;
    }
  }

  /// null when the passphrase is acceptable, or a message to show.
  static String? validatePassphrase(String passphrase) {
    if (passphrase.length < _minPassphraseLength) {
      return 'Use at least $_minPassphraseLength characters.';
    }
    return null;
  }

  static Future<String> encode(String plaintext, {required String passphrase}) async {
    final salt = _randomBytes(_saltBytes);
    final key = await _deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return jsonEncode({
      'format': envelopeFormat,
      'formatVersion': envelopeVersion,
      'cipher': _cipher,
      'kdf': _kdf,
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  /// Throws [SecretBoxAuthenticationError] on a wrong passphrase or a
  /// tampered file; [FormatException] on anything not shaped right.
  static Future<String> decode(String envelope, { required String passphrase}) async {
    final root = jsonDecode(envelope);
    if (root is! Map<String, dynamic> || root['format'] != envelopeFormat) {
      throw const FormatException("This isn't a Fuata encrypted backup.");
    }
    final version = root['formatVersion'];
    if (version is! int || version > envelopeVersion) {
      throw const FormatException(
        'This encrypted backup was made by a newer version of Fuata.',
      );
    }
    final iterations = root['iterations'];
    if (iterations is! int || iterations < 1000) {
      throw const FormatException('Bad KDF parameters in the file.');
    }
    final salt = _decodeBase64(root['salt']);
    final nonce = _decodeBase64(root['nonce']);
    final ciphertext = _decodeBase64(root['ciphertext']);
    final macBytes = _decodeBase64(root['mac']);

    final key = await _deriveKey(passphrase, salt, iterations: iterations);
    final algorithm = AesGcm.with256bits();
    final plaintext = await algorithm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
    return utf8.decode(plaintext);
  }

  static Future<SecretKey> _deriveKey(
      String passphrase,
      List<int> salt, {
        int iterations = _iterations,
      }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static List<int> _randomBytes(int n) {
    final rng = Random.secure();
    return List<int>.generate(n, (_) => rng.nextInt(256));
  }

  static List<int> _decodeBase64(Object? raw) {
    if (raw is! String) throw const FormatException('Missing field.');
    try {
      return base64Decode(raw);
    } on FormatException {
      throw const FormatException('Bad base64 in the file.');
    }
  }
}