import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../domain/models/settings.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../../widgets/personalization/toggle_row.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Security (issue #28): the app-lock switch that #28's scaffolding has
/// been waiting for since the SQLCipher half landed.
///
/// The lock is enforced by [lockedProvider] in app_router.dart — turning
/// it on here flips the redirect that sends an unlocked session to /lock.
/// This screen only collects the preference; the routing layer is what
/// makes it real.
///
/// Not in the backup (ADR-011): the lock is a property of *this* device,
/// not of the person's money. Restoring a file onto a new phone must not
/// silently lock them out of an app they just installed.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _auth = LocalAuthentication();

  /// Null until the first check returns — a tri-state so the row can say
  /// "Checking…" rather than flashing "no biometrics" for a frame.
  bool? _biometricAvailable;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool available;
    try {
      available = (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // A device that can't answer the question is treated as "no
      // biometrics" — same as one that has none. device-credential
      // unlock still works either way.
      available = false;
    }
    if (mounted) setState(() => _biometricAvailable = available);
  }

  void _update(AppSettings Function(AppSettings) fn) {
    final current = ref.read(currentSettingsProvider);
    ref.read(settingsRepositoryProvider).updateSettings(fn(current));
  }

  /// Turning app lock on is confirmed first, so the person proves *now*
  /// that the sensor on this device works, rather than discovering a
  /// problem at the moment they actually need back in.
  ///
  /// This also catches the "no screen lock configured" case: local_auth
  /// throws on authenticate() when the device has neither biometrics nor
  /// a PIN, and refusing to enable is the right answer — the alternative
  /// is a lock screen that can't be dismissed.
  Future<void> _setAppLock(bool enabled) async {
    if (!enabled) {
      _update((s) => s.copyWith(appLockEnabled: false));
      return;
    }

    bool ok;
    try {
      ok = await _auth.authenticate(
        localizedReason: 'Confirm it’s you to turn on App lock',
        authMessages: const [],
        // Not biometric-only here: a phone PIN is a perfectly good
        // second factor, and the *enabling* step should be the same
        // prompt the person will see later.
        biometricOnly: false,
      );
    } on PlatformException catch (e) {
      if (mounted) _explainSetupFailure(e);
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not turn on App lock, please try again')),
        );
      }
      return;
    }

    if (!mounted || !ok) return;
    _update((s) => s.copyWith(appLockEnabled: true));
  }

  void _explainSetupFailure(PlatformException e) {
    final message = switch (e.code) {
      'NotAvailable' || 'NotEnrolled' =>
      'Set a screen lock (PIN, pattern or fingerprint) in Android’s '
          'settings first, then try again.',
      'LockedOut' || 'PermanentlyLockedOut' =>
      'Too many tries. Unlock your phone, then try again.',
      _ => 'Could not turn on App lock: ${e.message ?? e.code}',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final bioReady = _biometricAvailable ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              title: 'App lock',
              children: [
                Text(
                  'When this is on, Fuata asks you to unlock before showing '
                      'your money — on every launch, and again after you leave '
                      'the app. Nothing leaves the phone either way; this is '
                      'only about someone else picking up your phone while it '
                      'is unlocked.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ToggleRow(
                  title: 'Require unlock to open Fuata',
                  subtitle: settings.appLockEnabled
                      ? 'On — ask on launch and after backgrounding.'
                      : 'Off — Fuata opens without asking.',
                  value: settings.appLockEnabled,
                  onChanged: _setAppLock,
                ),
                const SizedBox(height: AppSpacing.sm),
                ToggleRow(
                  title: 'Use fingerprint or face',
                  subtitle: _biometricAvailable == null
                      ? 'Checking…'
                      : bioReady
                      ? (settings.appLockBiometric
                      ? 'On — fingerprint or face first, then your phone PIN.'
                      : 'Off — use your phone PIN.')
                      : 'No fingerprint or face is set up on this phone.',
                  value: settings.appLockBiometric && bioReady,
                  // Two independent reasons the toggle can't move: the
                  // lock itself is off, or this phone has no biometrics
                  // to offer. Both read as a disabled switch, and the
                  // subtitle says which.
                  onChanged: (!settings.appLockEnabled || !bioReady)
                      ? null
                      : (v) => _update((s) => s.copyWith(appLockBiometric: v)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              // Three different locks, three different switches — the
              // two on Privacy & data hide numbers, this one asks who
              // you are. Worth spelling out so nobody hunts for the
              // wrong toggle.
              'Looking for the other locks? “Hide amounts in the app” and '
                  '“Hide in app switcher” are on Privacy & data. Those hide '
                  'numbers; this one asks who you are.',
              style: AppTypography.textTheme(
                c.onSurface,
                c.onSurfaceVariant,
              ).bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}