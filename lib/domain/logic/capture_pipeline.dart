// ---------------------------------------------------------------------------
// The capture pipeline (issues #21 and #22): turns one message — pasted,
// shared, or read from an allowed app's notification — into a pending (or
// auto-accepted) transaction, a duplicate no-op, or an unparsed capture.
//
// This used to live inside CaptureService in capture_providers.dart and
// took a Riverpod `Ref`. The notification listener (#22) runs it in a
// *background isolate* with no ProviderScope and no widgets, so the logic
// moved here: it depends only on repository interfaces, which means the
// UI isolate and the background isolate run literally the same code, and
// it can be unit-tested without a device (test/domain/capture_pipeline_test.dart).
// CaptureService is now a thin Riverpod wrapper around it.
// ---------------------------------------------------------------------------
import 'package:fuata/domain/logic/parser.dart';
import 'package:fuata/domain/logic/serial_queue.dart';

import '../models/transaction.dart';
import '../repositories/repositories.dart';
import 'dedupe.dart';

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

/// Nothing to do, and nothing stored: empty text, or (for notifications)
/// an app that isn't on the allow-list.
class CaptureIgnored extends CaptureOutcome {
  const CaptureIgnored();
}

class CaptureProcessor {
  CaptureProcessor({
    required this._units,
    required this._templates,
    required this._transactions,
    required this._captures,
    required this._sources,
    required this._settings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final UnitRepository _units;
  final TemplateRepository _templates;
  final TransactionRepository _transactions;
  final CaptureRepository _captures;
  final CaptureSourceRepository _sources;
  final SettingsRepository _settings;
  final DateTime Function() _now;

  final _queue = SerialQueue();

/// A notification posted by [packageName] (#22). The native listener has
/// already dropped anything not on the allow-list before it ever woke
/// Dart; this checks again against the database, so the guarantee in
/// US-10 — "non-allowed notifications are discarded immediately and
/// never stored" — holds even if the native copy of the list is stale.
  Future<CaptureOutcome> captureNotification(String packageName, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const CaptureIgnored();

    final sources = await _sources.watchSources().first;
    final allowed = sources.any((s) => s.enabled && s.packageName == packageName);
    if (!allowed) return const CaptureIgnored();

    return capture(
      trimmed,
      source: TxSource.notification,
      sourcePackage: packageName,
    );
  }

  /// Parses a message against the units' templates, dedupes against what's
  /// already stored, and inserts a pending row — or records an unparsed
  /// capture for the "Couldn't read these" list. This is where
  /// testing.md's P-07/P-08 dedupe cases actually run.
  Future<CaptureOutcome> capture(
      String text, {
        required TxSource source,
        String sourcePackage = 'shared',
      }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value(const CaptureIgnored());
    return _queue.run(() => _capture(trimmed, source, sourcePackage));
  }

  Future<CaptureOutcome> _capture(
      String trimmed,
      TxSource source,
      String sourcePackage,
      ) async {
    // Read fresh from the repositories — never from a StreamProvider's
    // .future (hangs if nothing is watching) or .value (empty until
    // something has watched). `.first` always resolves.
    final units = await _units.watchUnits().first;
    final templates = await _templates.watchTemplates().first;

    if (units.isEmpty) {
      // Nothing to attach a transaction to — keep the message teachable.
      await _recordUnparsed(sourcePackage, trimmed);
      return const CaptureUnparsed();
    }

    // Try each unit's templates in turn; a message belongs to whichever
    // unit's rules match it (P-06 picks between templates *within* a
    // unit — the unit itself is whoever matches first).
    for (final unit in units) {
      final unitTemplates = templates.where((t) => t.unitId == unit.id).toList();
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
      final now = _now();
      final occurredAt = fields.occurredAt ?? now;

      final all = await _transactions.watchTransactions().first;
      if (Dedupe.isDuplicate(
        all,
        unitId: unit.id,
        amountMinor: signed,
        at: occurredAt,
        code: fields.code,
      )) {
        return const CaptureDuplicate();
      }

      final autoAccept = (await _settings.watchSettings().first).autoAcceptCaptures;
      final status = autoAccept ? TxStatus.confirmed : TxStatus.pending;
      final baseId = 'cap_${now.microsecondsSinceEpoch}';
      await _transactions.addTransaction(
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
        await _transactions.addTransaction(
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

  /// Same app + same text is one entry, not one per arrival. Notifications
  /// get re-posted (a chat app updating its notification, a listener
  /// rebind) and "Teach me" re-runs capture on the text it already holds,
  /// so without this the "Couldn't read these" list fills with copies.
  Future<void> _recordUnparsed(String sourcePackage, String rawText) async {
    final existing = await _captures.watchUnparsed().first;
    final already = existing.any(
          (u) => u.sourcePackage == sourcePackage && u.rawText == rawText,
    );
    if (already) return;
    await _captures.recordUnparsed(
      id: 'unp_${_now().microsecondsSinceEpoch}',
      sourcePackage: sourcePackage,
      rawText: rawText,
    );
  }
}