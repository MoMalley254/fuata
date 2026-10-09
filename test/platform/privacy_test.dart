// Issue #84: the channel call that makes FLAG_SECURE reachable from Dart.
//
// The OS-level behaviour (blank Recents card, blocked screenshots) can only
// be verified on a device — see testing.md. This covers the layer between:
// a rename of the method or the channel fails the test rather than silently
// doing nothing on device.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/constants/method_channels_constants.dart';
import 'package:fuata/platform/privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(privacyMethodName),
          (call) async {
        if (call.method == 'setSecure') {
          calls.add(call.arguments as bool);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(privacyMethodName),
      null,
    );
  });

  test('applySecure sends the flag over the fuata/privacy channel', () async {
    await applySecure(true);
    await applySecure(false);
    await applySecure(true);

    expect(calls, [true, false, true]);
  });

  test('a platform error is swallowed, not thrown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(privacyMethodName),
          (call) async {
        throw PlatformException(code: 'boom');
      },
    );

    // Must not throw: the caller is a UI-side sync provider, and a
    // window that fails to accept the flag is not worth crashing over.
    await expectLater(applySecure(true), completes);
  });
}