import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/widgets/personalization/section_card.dart';

import '../../domain/models/capture_source.dart';
import '../../platform/notification_capture.dart';
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

class AutoCatchScreen extends ConsumerStatefulWidget {
  const AutoCatchScreen({super.key});

  @override
  ConsumerState<AutoCatchScreen> createState() => _AutoCatchScreenState();
}

class _AutoCatchScreenState extends ConsumerState<AutoCatchScreen>
    with WidgetsBindingObserver {
  bool? _accessEnabled; // null until the first check returns
  List<InstalledApp>? _apps; // null while loading
  String _query = '';
  final _packageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccess();   // read the current grant — do not open settings
    // _handleTurnOnAccess();
    _loadApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _packageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Android's notification-access screen: re-check, so
    // the status card reflects what the person just did there.
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  /// Read the current notification-access grant and update the status card.
  /// A pure read: never opens a dialog, never opens Android's settings.
  Future<void> _refreshAccess() async {
    final enabled = await isNotificationAccessEnabled();
    if (!mounted) return;

    final wasNull = _accessEnabled == null;
    final changed = !wasNull && _accessEnabled != enabled;
    setState(() => _accessEnabled = enabled);

    // Only speak up when the person just came back from a *change*: on a
    // fresh open, and on a resume where nothing moved, the status card
    // already says everything.
    if (changed && enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access is on 🎉')),
      );
    }
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accessOn
                        ? c.statusSafeContainer
                        : c.statusWarningContainer,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.unitTileRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        accessOn
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        color: accessOn ? c.statusSafe : c.statusWarning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _accessEnabled == null
                              ? 'Checking…'
                              : accessOn
                              ? 'Access is on.'
                              : 'Access is off, so nothing is caught from '
                                    'notifications yet.',
                          style: AppTypography.bodySm.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ActionRow(
                  icon: Icons.notifications_active_outlined,
                  title: accessOn ? 'Manage access' : 'Turn on access',
                  subtitle: 'Opens Android’s notification access list',
                  onTap: _handleTurnOnAccess,
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
