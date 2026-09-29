// ---------------------------------------------------------------------------
// Capture providers (issues #21, #22): the review inbox's data, the
// CaptureService that turns a shared/pasted message into either a
// pending transaction or an unparsed-capture row, and the notification
// allow-list (#22). The capture logic itself lives in
// domain/logic/capture_pipeline.dart so the notification listener's
// background isolate can run the very same code without Riverpod.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/db/drift_repositories.dart';
import '../../domain/logic/capture_pipeline.dart';
import '../../domain/models/capture_source.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unparsed_capture.dart';
import '../../domain/repositories/repositories.dart';
import '../../main.dart';
import '../../platform/notification_capture.dart';
import '../../platform/share_intake.dart';
import '../screens/review_inbox_screen.dart';
import 'app_providers.dart';

// The outcome types moved to the domain layer with the pipeline; re-exported
// so every existing `import capture_providers.dart` keeps compiling.
export '../../domain/logic/capture_pipeline.dart'
    show
    CaptureOutcome,
    Captured,
    CaptureDuplicate,
    CaptureUnparsed,
    CaptureIgnored;

final captureRepositoryProvider = Provider<CaptureRepository>((ref) {
  return DriftCaptureRepository(ref.watch(appDatabaseProvider));
});

/// Everything sitting in the review inbox right now (US-11) — confirmed
/// rows are excluded by definition. Derived from transactionsProvider so
/// Home, Activity and the inbox can never disagree about what exists.
final pendingTransactionsProvider = Provider<List<MoneyTransaction>>((ref) {
  final txs = ref.watch(transactionsProvider).value ?? [];
  return txs.where((t) => !t.isConfirmed).toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
});

final unparsedCapturesProvider = StreamProvider<List<UnparsedCapture>>((ref) {
  return ref.watch(captureRepositoryProvider).watchUnparsed();
});

// --- Notification allow-list (#22, US-10) -----------------------------

final captureSourceRepositoryProvider = Provider<CaptureSourceRepository>((ref) {
  return DriftCaptureSourceRepository(ref.watch(appDatabaseProvider));
});

/// Every app the person has ever toggled, on or off.
final captureSourcesProvider = StreamProvider<List<CaptureSource>>((ref) {
  return ref.watch(captureSourceRepositoryProvider).watchSources();
});

/// Package names of the *enabled* sources — the allow-list itself.
final allowedPackagesProvider = Provider<Set<String>>((ref) {
  final sources = ref.watch(captureSourcesProvider).value ?? const [];
  return {
    for (final s in sources)
      if (s.enabled) s.packageName,
  };
});

/// Keeps the native listener's copy of the allow-list in step with the
/// database: once when the first value loads (so it is re-sent on every
/// app start) and again on every change. Started once from `Fuata`.
final allowListSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<CaptureSource>>>(captureSourcesProvider, (
      _,
      next,
      ) {
    final sources = next.value;
    // Not loaded yet: don't push an empty list that would briefly make
    // the listener discard everything.
    if (sources == null) return;
    setAllowedPackages([
      for (final s in sources)
        if (s.enabled) s.packageName,
    ]);
  }, fireImmediately: true);
});

/// The background isolate writes through its own database connection, so
/// this isolate's drift streams would never hear about a captured
/// notification. Native pings us after each write; we tell drift the
/// affected tables changed so Home, Activity and the inbox refresh.
final captureRefreshProvider = Provider<void>((ref) {
  final db = ref.watch(appDatabaseProvider);
  listenForCaptureChanges(
        () => db.markTablesUpdated([db.transactions, db.unparsedCaptures]),
  );
  ref.onDispose(() => listenForCaptureChanges(null));
});

/// Everything sitting in the review inbox right now: pending captures
/// waiting for a check, plus messages nothing could read yet. One number
/// for the "N caught" nudges on Home and Activity, so those agree with
/// the inbox about how many things are actually in there — an unreadable
/// message is still something the person needs to look at.
final reviewInboxCountProvider = Provider<int>((ref) {
  final pending = ref.watch(pendingTransactionsProvider).length;
  final unparsed = ref.watch(unparsedCapturesProvider).value?.length ?? 0;
  return pending + unparsed;
});

/// Parses a shared/pasted message via the shared [CaptureProcessor]. The
/// processor is built once and kept, so its serial queue also orders a
/// paste and a share that arrive together.
class CaptureService {
  CaptureService(this._ref);
  final Ref _ref;

  late final CaptureProcessor _processor = CaptureProcessor(
    units: _ref.read(unitRepositoryProvider),
    templates: _ref.read(templateRepositoryProvider),
    transactions: _ref.read(transactionRepositoryProvider),
    captures: _ref.read(captureRepositoryProvider),
    sources: _ref.read(captureSourceRepositoryProvider),
    settings: _ref.read(settingsRepositoryProvider),
  );

  Future<CaptureOutcome> capture(
      String text, {
        required TxSource source,
        String sourcePackage = 'shared',
      }) {
    return _processor.capture(
      text,
      source: source,
      sourcePackage: sourcePackage,
    );
  }
}

final captureServiceProvider = Provider<CaptureService>((ref) {
  return CaptureService(ref);
});

// Owns the share-intake subscription for the app's lifetime. RootShell
// used to do this in initState, but its subscription could end up
// orphaned across rebuilds; a keepAlive provider can't be.
final shareIntakeListenerProvider = Provider<void>((ref) {
  final sub = sharedTextStream.listen((text) async {
    final capture = ref.read(captureServiceProvider);
    final outcome = await capture.capture(text, source: TxSource.shared);

    ref.read(reviewInboxNudgeProvider.notifier).state++; // see below
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ReviewInboxScreen()),
    );
    // Snackbar via a global messenger key so we don't need a BuildContext.
    final msg = rootScaffoldMessengerKey.currentState;
    msg?.showSnackBar(SnackBar(content: Text(_outcomeMessage(outcome))));
  });
  ref.onDispose(sub.cancel);

  // Cold-start stash drain: if a share launched the app before this
  // provider existed, consume it now.
  final pending = consumePendingSharedText();
  if (pending != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final capture = ref.read(captureServiceProvider);
      final outcome = await capture.capture(pending, source: TxSource.shared);
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ReviewInboxScreen()),
      );
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(_outcomeMessage(outcome))),
      );
    });
  }
});

String _outcomeMessage(CaptureOutcome outcome) => switch (outcome) {
  Captured(:final autoAccepted) =>
  autoAccepted
      ? 'Caught it — already added to your money.'
      : 'Caught it — waiting for your check.',
  CaptureDuplicate() => 'Already caught that one.',
  CaptureUnparsed() => "Couldn't read that one yet — tap Teach me.",
  CaptureIgnored() => '',
};

// Bumps whenever a capture lands, so Home's "N waiting" nudge refreshes
// even without the transactions stream having to fire.
final reviewInboxNudgeProvider = StateProvider<int>((ref) => 0);