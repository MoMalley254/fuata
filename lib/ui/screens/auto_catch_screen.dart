import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/widgets/personalization/section_card.dart';
import 'package:go_router/go_router.dart';

import '../../domain/logic/listener_status.dart';
import '../../domain/models/capture_source.dart';
import '../../platform/notification_capture.dart';
import '../../routing/routes.dart';
import '../../widgets/permissions/app_to_watch_dialog.dart';
import '../../widgets/permissions/notification_access_primer.dart';
import '../../widgets/personalization/action_row.dart';
import '../../widgets/personalization/label.dart';
import '../../widgets/personalization/toggle_row.dart';
import '../providers/capture_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Auto-catch (issue #22, US-10, ui-design-brief.md section 7.12 "Message
/// reading — allowed apps"): the two things the person controls about
/// reading notifications — the Android notification-access grant, and
/// which apps Fuata may read at all.
///
/// The promise this screen makes, and the listener keeps: only apps
/// switched on here are ever read; a notification from any other app is
/// dropped the instant it arrives and never stored.
///
/// Issue #36: the status card has four states (off / unknown / active /
/// stalled) instead of on/off, because the grant alone does not prove
/// Android bound the listener (design.md 5.1). The wording is always
/// "looks inactive", never "broken": detection is a best guess.

class AutoCatchScreen extends ConsumerStatefulWidget {
  const AutoCatchScreen({super.key});

  @override
  ConsumerState<AutoCatchScreen> createState() => _AutoCatchScreenState();
}

class _AutoCatchScreenState extends ConsumerState<AutoCatchScreen>
    with WidgetsBindingObserver {
  ListenerReading? _reading; // null until the first check returns
  Timer? _recheck;
  bool _autoRebindTried = false; // once per visit; "Fix it" is the manual one
  bool _fixing = false;

  ListenerStatus? get _status => _reading?.status;

  /// The grant (not the binding): drives "Turn on / Manage access" and the
  /// "starts working once access is on" hint.
  bool? get _accessEnabled =>
      _status == null ? null : _status != ListenerStatus.off;
  List<InstalledApp>? _apps; // null while loading
  String _query = '';
  final _packageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccess();   // read the current status — do not open settings
    _loadApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recheck?.cancel();
    _packageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Android's notification-access screen: re-check, so
    // the status card reflects what the person just did there.
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  /// Read the current status and update the status card. A pure read: never
  /// opens a dialog, never opens Android's settings. (The one side effect is
  /// a cheap rebind request the first time the listener looks stalled.)
  Future<void> _refreshAccess() async {
    final reading = await getListenerStatus();
    if (!mounted) return;

    final wasGranted = _accessEnabled;
    final nowGranted = reading.status != ListenerStatus.off;
    final changed = wasGranted != null && wasGranted != nowGranted;
    setState(() => _reading = reading);

    // "Unknown" is a grace period that ends on its own, with no event to
    // tell us: look again shortly so it settles without a manual refresh.
    _recheck?.cancel();
    if (reading.status == ListenerStatus.unknown) {
      _recheck = Timer(const Duration(seconds: 10), _refreshAccess);
    }

    // Stalled: ask Android to bind us again. Covers the `am kill` case
    // (devlog #18); it does nothing for a never-bound MIUI grant, which is
    // what "Fix it" is for.
    if (reading.status == ListenerStatus.stalled && !_autoRebindTried) {
      _autoRebindTried = true;
      unawaited(requestListenerRebind());
    }

    // Only speak up when the person just came back from a *change*: on a
    // fresh open, and on a resume where nothing moved, the status card
    // already says everything.
    if (changed && nowGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access is on 🎉')),
      );
    }
  }

  /// "Fix it": try the cheap rebind first; if the listener still doesn't
  /// look bound, walk the person through the off→on toggle in Android's own
  /// settings — the path design.md 5.1 documents as working.
  Future<void> _handleFixIt() async {
    if (_fixing) return;
    setState(() => _fixing = true);
    await requestListenerRebind();
    // A successful rebind reconnects within moments.
    await Future<void>.delayed(const Duration(seconds: 2));
    await _refreshAccess();
    if (!mounted) return;
    setState(() => _fixing = false);

    if (_status == ListenerStatus.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-catch looks active again.')),
      );
      return;
    }

    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('One more step'),
        content: const Text(
          'Sometimes Android stops sending notifications to Fuata without '
          'telling it. Switching Fuata’s access off and on again in '
          'Android’s own list usually wakes it up.\n\n'
          'On the next screen, switch Fuata off, then on. Come back here '
          'and this will check again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open the list'),
          ),
        ],
      ),
    );
    if (open == true) await openNotificationAccessSettings();
  }

  /// The "Turn on access" / "Manage access" button: explain what's about to
  /// happen (F17), then send the person to Android's settings.
  ///
  /// When access is already on this is "Manage access": skip the primer and
  /// jump straight to Android, so the person isn't told about a dialog they
  /// already agreed to.
  Future<void> _handleTurnOnAccess() async {
    if (_accessEnabled != true) {
      final proceed = await showNotificationAccessPrimer(context);
      if (!proceed) return;
      if (!mounted) return;
    }
    await openNotificationAccessSettings();
  }

  Future<void> _loadApps() async {
    final apps = await listLaunchableApps();
    if (mounted) setState(() => _apps = apps);
  }

  bool _looksLikeMessagesApp(String packageName, String label) {
    final p = packageName.toLowerCase();
    final l = label.toLowerCase();
    return p.contains('messag') ||
        p.contains('sms') ||
        p.contains('mms') ||
        l.contains('message') ||
        l.contains('sms') ||
        l.contains('messaging');
  }

  /// Apps most people want first: their messages app, then anything that
  /// looks like a bank or M-PESA. Pure heuristic — the person is still the
  /// one choosing — but it stops the top of a long A–Z list being whatever
  /// happens to start with "A".
  bool _looksRecommended(String packageName, String label) {
    final p = packageName.toLowerCase();
    final l = label.toLowerCase();
    if (_looksLikeMessagesApp(packageName, label)) return true;
    return p.contains('safaricom') ||
        p.contains('mpesa') ||
        p.contains('bank') ||
        p.contains('equity') ||
        p.contains('kcb') ||
        p.contains('coop') ||
        l.contains('m-pesa') ||
        l.contains('mpesa') ||
        l.contains('bank') ||
        l.contains('co-op') ||
        l.contains('coop');
  }

  Future<void> _toggle(String packageName, String label, bool on) async {
    if (on) {
      final allowed = ref.read(allowedPackagesProvider);
      final isMessages = _looksLikeMessagesApp(packageName, label);
      final firstEver = allowed.isEmpty;

      if (firstEver || isMessages) {
        final proceed = await showAppsToWatchExplainer(
          context,
          appLabel: label,
          isMessagesApp: isMessages,
        );
        if (!proceed) return;
        if (!mounted) return;
      }

      // Access is off: it will start working the moment it's on, but the
      // person shouldn't be left wondering why nothing's happening.
      if (_accessEnabled != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "This will start working once notification access is on.",
            ),
            action: SnackBarAction(
              label: 'Turn on access',
              onPressed: _handleTurnOnAccess,
            ),
          ),
        );
      }
    }

    return ref
        .read(captureSourceRepositoryProvider)
        .saveSource(
          CaptureSource(
            id: CaptureSource.idFor(packageName),
            packageName: packageName,
            displayName: label,
            enabled: on,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allowed = ref.watch(allowedPackagesProvider);
    final sources = ref.watch(captureSourcesProvider).value ?? const [];

    // Installed apps, plus any watched app that is no longer installed
    // (kept visible so it can still be switched off).
    final byPackage = <String, String>{
      for (final a in _apps ?? const <InstalledApp>[]) a.packageName: a.label,
      for (final s in sources)
        if (s.enabled) s.packageName: s.displayName,
    };
    final q = _query.trim().toLowerCase();
    final rows =
        byPackage.entries
            .where(
              (e) =>
                  q.isEmpty ||
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) {
            int tier(MapEntry<String, String> e) {
              if (allowed.contains(e.key)) return 0;
              if (_looksRecommended(e.key, e.value)) return 1;
              return 2;
            }

            final t = tier(a).compareTo(tier(b));
            if (t != 0) return t;
            return a.value.toLowerCase().compareTo(b.value.toLowerCase());
          });

    final accessOn = _accessEnabled == true;
    final stalled = _status == ListenerStatus.stalled;

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Catch')),
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
              title: 'Notification access',
              children: [
                Text(
                  'Fuata can read the notification a bank or mobile-money message '
                  'makes and turn it into a transaction for you to check. It only '
                  'looks at the apps you switch on below, and only keeps '
                  'notifications that look like a payment. Chats, one-time codes '
                  'and everything else are dropped the moment they arrive and are '
                  'never stored. Nothing leaves this phone.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _StatusCard(status: _status),
                const SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.notifications_active_outlined,
                  title: accessOn ? 'Manage access' : 'Turn on access',
                  subtitle: 'Opens Android’s notification access list',
                  onTap: _handleTurnOnAccess,
                ),
                if (stalled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ActionRow(
                    icon: Icons.build_circle_outlined,
                    title: _fixing ? 'Checking…' : 'Fix it',
                    subtitle: 'Tries to wake Fuata up, then shows what to do',
                    onTap: _handleFixIt,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.battery_saver_outlined,
                  title: 'Keep Fuata running',
                  subtitle: 'Steps for phones that stop background apps',
                  onTap: () => context.push(Routes.keepAlivePath),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'If Fuata’s switch is greyed out, open Fuata’s App info, '
                  'tap ⋮ and choose “Allow restricted settings”. On some '
                  'phones the switch only takes effect after turning it '
                  'off and on again.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Apps to watch',
              children: [
                Text(
                  'Pick your messages app, and any bank or mobile-money app '
                  'that sends you payment notifications.',
                  style: AppTypography.bodySm.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search apps',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Debug builds only: lets `adb shell cmd notification post`
                // (posted as com.android.shell, which has no launcher icon
                // and so never appears above) be allow-listed for
                // testing.md's listener checks.
                if (kDebugMode) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _packageController,
                          decoration: const InputDecoration(
                            hintText: 'Add by package name (debug only)',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: () {
                          final pkg = _packageController.text.trim();
                          if (pkg.isEmpty) return;
                          _toggle(pkg, pkg, true);
                          _packageController.clear();
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_apps == null)
                  const Center(child: CircularProgressIndicator.adaptive())
                else if (rows.isEmpty)
                  Text(
                    byPackage.isEmpty
                        ? 'No apps found.'
                        : 'No app matches “$_query”.',
                    style: AppTypography.bodyMd.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  )
                else ...[
                  Label(
                    allowed.isEmpty
                        ? 'Not watching any apps yet'
                        : allowed.length == 1
                        ? 'Watching 1 app'
                        : 'Watching ${allowed.length} apps',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final e in rows) ...[
                    ToggleRow(
                      title: e.value,
                      subtitle: e.key,
                      value: allowed.contains(e.key),
                      onChanged: (v) => _toggle(e.key, e.value, v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The four-state status line (issue #36). "Looks", not "is": it is built
/// from Android's bind/unbind callbacks, which is evidence, not proof.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  /// Null until the first check returns.
  final ListenerStatus? status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (IconData icon, Color iconColor, Color? fill, String text) =
        switch (status) {
      null => (
        Icons.hourglass_empty_rounded,
        c.onSurfaceVariant,
        null,
        'Checking…',
      ),
      ListenerStatus.off => (
        Icons.info_outline_rounded,
        c.statusWarning,
        c.statusWarningContainer,
        'Access is off, so nothing is caught from notifications yet.',
      ),
      ListenerStatus.unknown => (
        Icons.hourglass_empty_rounded,
        c.onSurfaceVariant,
        null,
        'Access is on. Checking that Fuata is receiving notifications…',
      ),
      ListenerStatus.active => (
        Icons.check_circle_outline_rounded,
        c.statusSafe,
        c.statusSafeContainer,
        'Access is on and Auto-catch looks active.',
      ),
      ListenerStatus.stalled => (
        Icons.info_outline_rounded,
        c.statusWarning,
        c.statusWarningContainer,
        'Access is on, but Auto-catch doesn’t look active. Payments may '
            'be missed until it’s fixed.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fill,
        border: fill == null
            ? Border.all(color: c.outlineVariant.withValues(alpha: 0.35))
            : null,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
