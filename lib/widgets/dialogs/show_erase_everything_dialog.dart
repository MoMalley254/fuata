import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../platform/banner.dart';
import '../../platform/notification_capture.dart';
import '../../platform/widget_bridge.dart';
import '../../routing/app_keys.dart';
import '../../routing/routes.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

Future<void> eraseAllData(WidgetRef ref) async {
  // Step 1: offer a backup. The person just asked to destroy everything
  // on this phone; giving them a way to keep a copy first costs one tap
  // and might save years of history. "Back up first" navigates away, so
  // coming back here means they either backed up and returned, or changed
  // their mind.
  final proceed = await _showBackupPrompt();
  if (proceed != true) return;

  // Step 2: type ERASE. A second tap can be muscle-memoried away; typing
  // a word cannot. This is the one place in the app where the wrong
  // answer destroys everything, so it earns the extra beat.
  final confirmed = await _showTypeToConfirmDialog();
  if (confirmed != true) return;

  // Grab the messenger from the *root* key, not a local context: the
  // router redirects to /onboarding the moment the settings stream
  // reports the empty table, which unmounts the calling screen before the
  // snackbar would otherwise be shown.
  final messenger = rootScaffoldMessengerKey.currentState;
  try {
    await ref.read(backupRepositoryProvider).eraseAll();

    // The database is empty now. Take the three traces that live outside
    // it with it:
    //  - the posted banner, or it hangs around showing a stale number;
    //  - the native allow-list mirror, so the listener discards
    //    everything from here on (CaptureStore.isAllowed defaults to
    //    false for an empty set);
    //  - the home-widget snapshot, so the widget falls back to its
    //    "open Fuata" state rather than showing the numbers it had.
    //
    // Deliberately NOT touched: the registered capture callback handle
    // in CaptureStore — it is re-registered on every app start and has
    // no data in it, only a routing number. Clearing it here would just
    // be undone a moment later.
    await BannerPlatform.instance.cancel();
    await setAllowedPackages(const []);
    await AndroidHomeWidgetBridge().clear();

    // No explicit navigation: settings now read as a fresh install
    // (onboardingComplete: false), and the router's redirect sends the
    // person to onboarding on its own — which is the same landing an
    // install with no data would get.
    messenger?.showSnackBar(
      const SnackBar(content: Text('Everything erased.')),
    );
  } catch (_) {
    messenger?.showSnackBar(
      SnackBar(content: Text("Couldn't erase everything. Please try again.")),
    );
  }
}

/// Step 1 of the erase flow, as a SmartDialog. Resolves to `true` when the
/// person chose to continue with the erase, `false` for cancel or backup.
Future<bool> _showBackupPrompt() {
  final completer = Completer<bool>();

  void finish(bool value) {
    SmartDialog.dismiss();
    if (!completer.isCompleted) completer.complete(value);
  }

  SmartDialog.show(
    builder: (dialogContext) => AlertDialog(
      title: const Text('Erase everything?'),
      content: const Text(
        'This wipes every unit, transaction, limit, message rule and '
            'setting on this phone. It cannot be undone.\n\n'
            'Backup files you have already saved are not touched — those are '
            'yours, wherever you put them.',
      ),
      actions: [
        TextButton(
          onPressed: () => finish(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // The dialog's own context sits in SmartDialog's overlay,
            // above the navigator, so it has no GoRouter in its ancestry.
            // The root navigator key's context does — it is the very
            // navigator GoRouter drives.
            finish(false);
            rootNavigatorKey.currentContext?.push(Routes.backupPath);
          },
          child: const Text('Back up first'),
        ),
        FilledButton(
          onPressed: () => finish(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  return completer.future;
}

/// Step 2 of the erase flow. Resolves to `true` only if ERASE was typed
/// and the confirm button was pressed.
Future<bool> _showTypeToConfirmDialog() {
  final completer = Completer<bool>();

  SmartDialog.show(
    builder: (_) => _TypeToConfirmDialog(
      onResult: (value) {
        SmartDialog.dismiss();
        if (!completer.isCompleted) completer.complete(value);
      },
    ),
  );

  return completer.future;
}

/// The second step of the erase confirmation: type ERASE. Its own
/// StatefulWidget only because it needs to hold a controller and rebuild
/// as the typed text changes. It reports its answer through [onResult]
/// rather than by popping a route, since it is not on one.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({required this.onResult});

  final ValueChanged<bool> onResult;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  bool get _matches => _controller.text.trim().toUpperCase() == 'ERASE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Type ERASE to confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everything Fuata has stored on this phone will be deleted. '
                'This cannot be undone.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_matches) widget.onResult(true);
            },
            decoration: const InputDecoration(hintText: 'ERASE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onResult(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Disabled until the word is typed exactly. Not a "disable and
          // grey out" hint — the button is simply dead until the guard is
          // satisfied, which is what makes it a guard.
          onPressed: _matches ? () => widget.onResult(true) : null,
          child: const Text('Erase everything'),
        ),
      ],
    );
  }
}