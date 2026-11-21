import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/listener_status.dart';

void main() {
  // Issue #36. The status is a best guess built from Android's
  // onListenerConnected / onListenerDisconnected times; these tests pin the
  // rules, including the grace-period boundary and the boot case.

  final boot = DateTime(2026, 11, 20, 8, 0, 0);
  final t0 = DateTime(2026, 11, 20, 12, 0, 0); // "the grant" in most cases
  const grace = kListenerGrace;

  ListenerStatus status({
    bool granted = true,
    DateTime? connectedAt,
    DateTime? disconnectedAt,
    DateTime? grantedAt,
    DateTime? bootAt,
    required DateTime now,
  }) => computeListenerStatus(
    granted: granted,
    connectedAt: connectedAt,
    disconnectedAt: disconnectedAt,
    grantedAt: grantedAt,
    bootAt: bootAt ?? boot,
    now: now,
  );

  group('off', () {
    test('not granted is off, whatever else is recorded', () {
      expect(
        status(
          granted: false,
          connectedAt: t0,
          grantedAt: t0,
          now: t0.add(const Duration(hours: 1)),
        ),
        ListenerStatus.off,
      );
    });
  });

  group('active', () {
    test('connected after the grant and never disconnected', () {
      expect(
        status(
          grantedAt: t0,
          connectedAt: t0.add(const Duration(seconds: 5)),
          now: t0.add(const Duration(hours: 3)),
        ),
        ListenerStatus.active,
      );
    });

    test('connect at the same instant as the grant counts', () {
      // The listener stamps the grant itself when it connects first.
      expect(
        status(grantedAt: t0, connectedAt: t0, now: t0.add(grace * 5)),
        ListenerStatus.active,
      );
    });

    test('active without a recorded grant time: judged against boot', () {
      expect(
        status(
          connectedAt: boot.add(const Duration(seconds: 30)),
          now: boot.add(const Duration(hours: 2)),
        ),
        ListenerStatus.active,
      );
    });

    test('disconnected, then reconnected', () {
      expect(
        status(
          grantedAt: t0,
          connectedAt: t0.add(const Duration(minutes: 10)),
          disconnectedAt: t0.add(const Duration(minutes: 5)),
          now: t0.add(const Duration(hours: 1)),
        ),
        ListenerStatus.active,
      );
    });

    test('disconnect and reconnect at the same instant counts as connected', () {
      final same = t0.add(const Duration(minutes: 5));
      expect(
        status(
          grantedAt: t0,
          connectedAt: same,
          disconnectedAt: same,
          now: t0.add(const Duration(hours: 1)),
        ),
        ListenerStatus.active,
      );
    });
  });

  group('unknown (inside the grace period)', () {
    test('just granted, nothing connected yet', () {
      expect(
        status(grantedAt: t0, now: t0.add(const Duration(seconds: 10))),
        ListenerStatus.unknown,
      );
    });

    test('just booted, nothing connected yet', () {
      expect(
        status(now: boot.add(const Duration(seconds: 20))),
        ListenerStatus.unknown,
      );
    });

    test('just disconnected: a rebind has only just been requested', () {
      final dc = t0.add(const Duration(hours: 1));
      expect(
        status(
          grantedAt: t0,
          connectedAt: t0.add(const Duration(seconds: 5)),
          disconnectedAt: dc,
          now: dc.add(const Duration(seconds: 10)),
        ),
        ListenerStatus.unknown,
      );
    });
  });

  group('stalled', () {
    test('granted, never connected, grace over (the MIUI adb-grant case)', () {
      expect(
        status(grantedAt: t0, now: t0.add(grace + const Duration(seconds: 1))),
        ListenerStatus.stalled,
      );
    });

    test('disconnected and not reconnected, grace over (the am kill case)', () {
      final dc = t0.add(const Duration(hours: 1));
      expect(
        status(
          grantedAt: t0,
          connectedAt: t0.add(const Duration(seconds: 5)),
          disconnectedAt: dc,
          now: dc.add(grace + const Duration(seconds: 1)),
        ),
        ListenerStatus.stalled,
      );
    });

    test('a connect from before the last boot does not count', () {
      // Connected yesterday, phone rebooted since, nothing connected today.
      expect(
        status(
          connectedAt: boot.subtract(const Duration(hours: 6)),
          now: boot.add(grace + const Duration(minutes: 1)),
        ),
        ListenerStatus.stalled,
      );
    });

    test('a connect from before a re-grant does not count', () {
      // Revoked and granted again: the old connect belongs to the old grant.
      expect(
        status(
          connectedAt: t0.subtract(const Duration(days: 1)),
          grantedAt: t0,
          now: t0.add(grace + const Duration(minutes: 1)),
        ),
        ListenerStatus.stalled,
      );
    });

    test('a grant older than boot is ignored in favour of boot', () {
      // grantedAt is from before the reboot; the boot is the real start.
      expect(
        status(
          grantedAt: boot.subtract(const Duration(days: 3)),
          now: boot.add(grace + const Duration(minutes: 1)),
        ),
        ListenerStatus.stalled,
      );
    });
  });

  group('grace boundary', () {
    test('one millisecond inside the grace period is still unknown', () {
      expect(
        status(
          grantedAt: t0,
          now: t0.add(grace - const Duration(milliseconds: 1)),
        ),
        ListenerStatus.unknown,
      );
    });

    test('exactly at the grace period it is stalled', () {
      expect(
        status(grantedAt: t0, now: t0.add(grace)),
        ListenerStatus.stalled,
      );
    });

    test('a custom grace period is honoured', () {
      expect(
        computeListenerStatus(
          granted: true,
          connectedAt: null,
          disconnectedAt: null,
          grantedAt: t0,
          bootAt: boot,
          now: t0.add(const Duration(seconds: 31)),
          grace: const Duration(seconds: 30),
        ),
        ListenerStatus.stalled,
      );
    });
  });
}
