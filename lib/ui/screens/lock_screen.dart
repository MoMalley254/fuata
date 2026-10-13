// lib/ui/screens/lock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _auth = LocalAuthentication();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final s = ref.read(currentSettingsProvider);

      // Ask for biometric-only only if a sensor is actually enrolled
      // right now. The preference was written when the person set this
      // up; fingerprints can have been removed since. Passing
      // biometricOnly: true on a phone with none throws, and an error
      // string on a lock screen is a person who can't get in.
      var biometricOnly = s.appLockBiometric;
      if (biometricOnly) {
        final enrolled = await _auth.getAvailableBiometrics();
        if (enrolled.isEmpty) biometricOnly = false;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Fuata to see your money',
        authMessages: const [],
        biometricOnly: biometricOnly,
      );

      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Not unlocked.');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = _explain(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not unlock: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Turn local_auth's platform error codes into something a person can
  /// act on. The commonest by far is "no screen lock configured": they
  /// had one, then removed it in Android settings — Fuata can't verify
  /// them any more, and the fix is on their side.
  String _explain(PlatformException e) => switch (e.code) {
    'NotAvailable' || 'NotEnrolled' =>
    'This phone has no screen lock set up. Set a PIN, pattern or '
        'fingerprint in Android’s settings, then try again.',
    'LockedOut' =>
    'Too many tries. Unlock your phone with its PIN, then try again.',
    'PermanentlyLockedOut' =>
    'Unlock your phone with its PIN, then try again.',
    _ => 'Could not unlock: ${e.message ?? e.code}',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 56, color: c.primary),
                const SizedBox(height: AppSpacing.lg),
                Text('Fuata is locked',
                    style: AppTypography.headlineSm.copyWith(color: c.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Unlock to see your money.',
                  style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!,
                      style: AppTypography.bodySm.copyWith(color: c.statusDanger)),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _busy ? null : _prompt,
                  child: Text(_busy ? 'Waiting…' : 'Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}