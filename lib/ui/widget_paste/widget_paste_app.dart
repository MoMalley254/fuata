// ---------------------------------------------------------------------------
// The home-screen widget's Paste flow (issue #153).
//
// Runs in its own Flutter engine inside the transparent WidgetPasteActivity:
// no router, no onboarding gate, none of the app's startup. It reads the
// clipboard, runs it through the same PasteParser as the add-transaction
// sheet's Paste button, and — on success — shows that same sheet pre-filled,
// so category, note, fee and date are all editable before Save.
//
// A successful save is *confirmed* money, exactly like the sheet: the
// person has just looked at the extracted details and pressed Save, which is
// the review. (A capture notification needs Accept/Fix because nobody has
// looked at it yet.)
//
// Like the capture isolate, it opens its own AppDatabase, closes it when
// done, and calls refreshDerivedState so the banner, alerts and widget catch
// up, then pings a running UI to re-query.
//
// Startup-delay work (follow-up 6.1):
//   * every stage is timestamped ([widget-paste] in logcat) so the delay can
//     be measured on a release build instead of guessed at;
//   * the first frame is a "Reading your message…" card, never a bare scrim;
//   * clipboard, settings, units and templates load in parallel;
//   * the database connection is warmed before the first frame.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../domain/logic/paste_parser.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/template.dart';
import '../../domain/models/unit.dart';
import '../../platform/banner.dart';
import '../../platform/notification_capture.dart';
import '../../platform/widget_paste.dart';
import '../providers/app_providers.dart';
import '../screens/lock_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../../widgets/sheets/add_transaction_sheet.dart';

/// Stage timestamps for the tap-to-sheet delay. Prints in every build mode
/// (the point is to measure *release*); filter with
/// `adb logcat -s widget-paste flutter`.
class _Timeline {
  _Timeline._();
  static final Stopwatch _sw = Stopwatch();

  static void start() {
    _sw
      ..reset()
      ..start();
    mark('widgetPasteMain entered');
  }

  static void mark(String stage) =>
      debugPrint('[widget-paste] +${_sw.elapsedMilliseconds}ms  $stage');
}

/// Called from `widgetPasteMain` in main.dart. (The Dart entry point has to
/// live in the root library for the activity to find it by name.)
void runWidgetPaste() {
  WidgetsFlutterBinding.ensureInitialized();
  _Timeline.start();
  traceDbOpen = true;

  final db = AppDatabase();

  // Warm the connection now. AppDatabase is lazy: the first query reads the
  // key from Keystore and opens the file, so doing it here overlaps that
  // cost with engine start and the first frame instead of adding to them.
  unawaited(
    db
        .customSelect('SELECT 1')
        .get()
        .then((_) => _Timeline.mark('db ready'))
        .catchError((Object _) {
      _Timeline.mark('db warm-up failed (the flow will surface the error)');
      return <QueryRow>[];
    }),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    _Timeline.mark('first frame');
    final native = await WidgetPasteChannel.msSinceCreate();
    if (native != null) {
      debugPrint('[widget-paste] first frame at ${native}ms after native onCreate');
    }
  });

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: _WidgetPasteApp(db: db),
    ),
  );
}

class _WidgetPasteApp extends ConsumerWidget {
  const _WidgetPasteApp({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode.flutterThemeMode,
      theme: AppTheme.light(accent: settings.accent),
      darkTheme: AppTheme.dark(accent: settings.accent),
      color: Colors.transparent,
      home: _WidgetPasteFlow(db: db),
    );
  }
}

class _Loaded {
  const _Loaded({required this.lockRequired, required this.text, required this.result});
  final bool lockRequired;
  final String? text;
  final PasteParseResult? result;
}

class _WidgetPasteFlow extends ConsumerStatefulWidget {
  const _WidgetPasteFlow({required this.db});
  final AppDatabase db;

  @override
  ConsumerState<_WidgetPasteFlow> createState() => _WidgetPasteFlowState();
}

class _WidgetPasteFlowState extends ConsumerState<_WidgetPasteFlow> {
  late final Future<_Loaded> _loaded = _load();
  bool _unlocked = false;

  Future<_Loaded> _load() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final unitsRepo = ref.read(unitRepositoryProvider);
    final templatesRepo = ref.read(templateRepositoryProvider);

    // All four at once. The clipboard may wait for window focus on the
    // native side; the database reads don't need to wait behind it. Templates
    // are read in one query and grouped by unit, not one query per unit.
    final results = await Future.wait<Object?>([
      WidgetPasteChannel.readClipboard()
          .then((v) { _Timeline.mark('clipboard returned'); return v; }),
      settingsRepo.watchSettings().first
          .then((v) { _Timeline.mark('settings read'); return v; }),
      unitsRepo.watchUnits().first
          .then((v) { _Timeline.mark('units read'); return v; }),
      templatesRepo.watchTemplates().first
          .then((v) { _Timeline.mark('templates read'); return v; }),
    ]);

    final text = results[0] as String?;
    final settings = results[1] as AppSettings;
    final units = results[2] as List<MoneyUnit>;
    final allTemplates = results[3] as List<CaptureTemplate>;

    final byUnit = <String, List<CaptureTemplate>>{};
    for (final t in allTemplates) {
      (byUnit[t.unitId] ??= <CaptureTemplate>[]).add(t);
    }

    final result = text == null
        ? null
        : PasteParser.parse(
      text,
      units: units,
      templatesByUnit: byUnit,
    );
    _Timeline.mark('parse done');

    return _Loaded(
      lockRequired: settings.appLockEnabled,
      text: text,
      result: result,
    );
  }

  Future<void> _close([String? message]) async {
    try {
      await widget.db.close();
    } catch (_) {}
    await WidgetPasteChannel.finish(message: message);
  }

  Future<void> _openApp() async {
    try {
      await widget.db.close();
    } catch (_) {}
    await WidgetPasteChannel.openApp();
  }

  /// The sheet saved. Never throws: the row is already written, so a banner
  /// or alert failure must not look like a failed save.
  Future<void> _onSaved(String message) async {
    try {
      await BannerPlatform.instance.init();
      await refreshDerivedState(widget.db);
    } catch (_) {}
    pingUiAfterCaptureAction();
    await _close(message);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Loaded>(
      future: _loaded,
      builder: (context, snap) {
        if (snap.hasError) {
          return _frame(
            _NoticeCard(
              title: "Couldn't open your money",
              body: 'Open Fuata and try again.',
              onClose: _close,
              onOpenApp: _openApp,
            ),
          );
        }
        final data = snap.data;
        // Something on the very first frame, so the tap never feels ignored.
        if (data == null) return _frame(const _LoadingCard());

        // App lock: the sheet shows amounts and writes to the ledger, so it
        // sits behind the same unlock as the app.
        if (data.lockRequired && !_unlocked) {
          return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
        }

        if (data.text == null) {
          return _frame(
            _NoticeCard(
              title: 'Nothing to paste',
              body: 'Copy the payment message first, then tap paste again.',
              onClose: _close,
            ),
          );
        }

        final failure = data.result?.failure;
        if (failure != null) {
          return _frame(
            _NoticeCard(
              title: failure == PasteFailure.unreadable
                  ? "Couldn't read that"
                  : 'Not set up yet',
              body: failure.message,
              onClose: _close,
              onOpenApp: _openApp,
            ),
          );
        }

        final parsed = data.result!.parsed!;
        return _frame(
          AddTransactionSheet(
            initialUnitId: parsed.unitId,
            initialParsed: parsed,
            onSaved: _onSaved,
          ),
        );
      },
    );
  }

  /// Scrim + bottom-anchored content. A tap on the scrim closes.
  Widget _frame(Widget child) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // The sheet pads for the keyboard itself.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(color: Colors.black54),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown from the first frame until the message has been read and parsed.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Sheet(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Reading your message…',
              style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.body,
    required this.onClose,
    this.onOpenApp,
  });
  final String title;
  final String body;
  final VoidCallback onClose;
  final VoidCallback? onOpenApp;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Sheet(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.labelMd.copyWith(color: c.onSurface)),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onClose, child: const Text('Close')),
                if (onOpenApp != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(onPressed: onOpenApp, child: const Text('Open Fuata')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}