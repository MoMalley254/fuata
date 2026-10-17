import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/backup_crypto.dart';

void main() {
  const passphrase = 'correct horse battery staple';
  const plaintext = '{"format":"fuata-backup","formatVersion":1,"data":{}}';

  group('encode / decode round trip', () {
    test('the same passphrase decrypts what it encrypted', () async {
      final envelope = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      expect(await BackupCrypto.decode(envelope, passphrase: passphrase), plaintext);
    });

    test('a wrong passphrase fails the MAC', () async {
      final envelope = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      await expectLater(
            () => BackupCrypto.decode(envelope, passphrase: 'wrong passphrase'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('a tampered ciphertext fails the MAC', () async {
      final envelope = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      // Flip one byte of the encoded ciphertext string.
      final root = jsonDecode(envelope) as Map<String, dynamic>;
      final ct = base64Decode(root['ciphertext'] as String);
      ct[0] = ct[0] ^ 0xFF;
      root['ciphertext'] = base64Encode(ct);
      await expectLater(
            () => BackupCrypto.decode(jsonEncode(root), passphrase: passphrase),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('two encryptions of the same plaintext differ', () async {
      final a = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      final b = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      expect(a, isNot(b));
    });
  });

  group('looksEncrypted', () {
    test('an envelope returns true', () async {
      final envelope = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      expect(BackupCrypto.looksEncrypted(envelope), isTrue);
    });
    test('a plaintext backup returns false', () {
      expect(BackupCrypto.looksEncrypted(plaintext), isFalse);
    });
    test('random text returns false', () {
      expect(BackupCrypto.looksEncrypted('not json'), isFalse);
      expect(BackupCrypto.looksEncrypted('{"format":"else"}'), isFalse);
    });
  });

  group('validatePassphrase', () {
    test('too short rejected', () {
      expect(BackupCrypto.validatePassphrase('short'), isNotNull);
    });
    test('long enough accepted', () {
      expect(BackupCrypto.validatePassphrase('longenough'), isNull);
    });
  });

  group('refuses bad envelopes', () {
    test('wrong format', () async {
      await expectLater(
            () => BackupCrypto.decode('{"format":"nope"}', passphrase: passphrase),
        throwsA(isA<FormatException>()),
      );
    });
    test('newer version', () async {
      final envelope = await BackupCrypto.encode(plaintext, passphrase: passphrase);
      final root = jsonDecode(envelope) as Map<String, dynamic>;
      root['formatVersion'] = 99;
      await expectLater(
            () => BackupCrypto.decode(jsonEncode(root), passphrase: passphrase),
        throwsA(isA<FormatException>()),
      );
    });
  });
}