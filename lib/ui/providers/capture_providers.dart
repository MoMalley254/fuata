// ---------------------------------------------------------------------------
// Capture providers (issue #21): the review inbox's data plus the
// CaptureService that turns a shared/pasted message into either a
// pending transaction or an unparsed-capture row. Notifications (#22)
// reuse this exact service and inbox.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/db/drift_repositories.dart';
import '../../domain/logic/dedupe.dart';
import '../../domain/logic/parser.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unparsed_capture.dart';
import '../../domain/repositories/repositories.dart';
import '../../main.dart';
import '../../platform/share_intake.dart';
import '../screens/review_inbox_screen.dart';
import 'app_providers.dart';

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

/// What became of one captured message — the share-intake listener and
/// the inbox's paste button use this to tell the person what happened
/// (or, for duplicates, that nothing needed to happen).
sealed class CaptureOutcome {
  const CaptureOutcome();
}

class Captured extends CaptureOutcome {
  final String transactionId;

  /// True when the auto-accept setting confirmed it immediately, so the
  /// caller's message can say "already added" instead of "waiting".
  final bool autoAccepted;
  const Captured(this.transactionId, {this.autoAccepted = false});
}

class CaptureDuplicate extends CaptureOutcome {
  const CaptureDuplicate();
}

class CaptureUnparsed extends CaptureOutcome {
  const CaptureUnparsed();
}

class CaptureIgnored extends CaptureOutcome {
  const CaptureIgnored();
}

/// Parses a shared/pasted message against the units' templates, dedupes
/// against what's already stored, and inserts a pending row — or records
/// an unparsed capture for the "Couldn't read these" list. This is where
/// testing.md's P-07/P-08 dedupe cases actually run.
class CaptureService {
  CaptureService(this._ref);
  final Ref _ref;

  Future<CaptureOutcome> capture(
    String text, {
    required TxSource source,
    String sourcePackage = 'shared',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const CaptureIgnored();

    // Read fresh from the repositories — never from a StreamProvider's
    // .future (hangs if nothing is watching) or .value (empty until
    // something has watched). `.first` always resolves.
    final units = await _ref.read(unitRepositoryProvider).watchUnits().first;
    final templates = await _ref
        .read(templateRepositoryProvider)
        .watchTemplates()
        .first;

    if (units.isEmpty) {
      // Nothing to attach a transaction to — keep the message teachable.
      await _recordUnparsed(sourcePackage, trimmed);
      return const CaptureUnparsed();
    }

    // Try each unit's templates in turn; a message belongs to whichever
    // unit's rules match it (P-06 picks between templates *within* a
    // unit — the unit itself is whoever matches first).
    for (final unit in units) {
      final unitTemplates = templates
          .where((t) => t.unitId == unit.id)
          .toList();
      if (unitTemplates.isEmpty) continue;

      final result = Parser.parse(
        trimmed,
        unitTemplates,
        currencyCode: unit.currencyCode,
      );
      if (!result.matched) continue;
      final fields = result.fields;
      if (fields == null || fields.amountMinor == null) continue;

      final type = result.type ?? TxType.spent;
      final signed = type == TxType.got
          ? fields.amountMinor!
          : -fields.amountMinor!;
      final occurredAt = fields.occurredAt ?? DateTime.now();

      final all = await _ref.read(transactionsProvider.future);
      if (Dedupe.isDuplicate(
        all,
        unitId: unit.id,
        amountMinor: signed,
        at: occurredAt,
        code: fields.code,
      )) {
        return const CaptureDuplicate();
      }

      final autoAccept = _ref.read(currentSettingsProvider).autoAcceptCaptures;
      final status = autoAccept ? TxStatus.confirmed : TxStatus.pending;
      final repo = _ref.read(transactionRepositoryProvider);
      final now = DateTime.now();
      final baseId = 'cap_${now.microsecondsSinceEpoch}';
      await repo.addTransaction(
        MoneyTransaction(
          id: baseId,
          unitId: unit.id,
          type: type,
          amountMinor: signed,
          counterparty: fields.counterparty,
          code: fields.code,
          occurredAt: occurredAt,
          createdAt: now,
          source: source,
          status: status,
          templateId: result.template!.id,
          balanceAfterMinor: fields.balanceAfterMinor,
          // rawText stays null — raw messages are opt-in only (ADR-009);
          // only unparsed captures keep text, because that's their point.
        ),
      );
      if (fields.feeMinor != null && fields.feeMinor! > 0) {
        // ADR-005: the fee is its own child `spent` row, pending too, so
        // it confirms — or is discarded — together with its parent.
        await repo.addTransaction(
          MoneyTransaction(
            id: '${baseId}_fee',
            unitId: unit.id,
            type: TxType.spent,
            amountMinor: -fields.feeMinor!,
            counterparty: 'Fee',
            occurredAt: occurredAt,
            createdAt: now,
            source: source,
            status: status,
            parentId: baseId,
          ),
        );
      }
      return Captured(baseId, autoAccepted: autoAccept);
    }

    await _recordUnparsed(sourcePackage, trimmed);
    return const CaptureUnparsed();
  }

  Future<void> _recordUnparsed(String sourcePackage, String rawText) {
    return _ref
        .read(captureRepositoryProvider)
        .recordUnparsed(
          id: 'unp_${DateTime.now().microsecondsSinceEpoch}',
          sourcePackage: sourcePackage,
          rawText: rawText,
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
