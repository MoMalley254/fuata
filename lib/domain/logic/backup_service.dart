// ---------------------------------------------------------------------------
// The three things the Back up & restore screen does (issue #24), with no
// UI and no file access in the way so they can be tested end to end
// against an in-memory database:
//
//   buildExport - read everything, encode it.
//   preview     - decode a file, compare it with the phone. Writes nothing.
//   apply       - write what the person confirmed, in one transaction.
// ---------------------------------------------------------------------------

import '../models/backup_snapshot.dart';
import '../repositories/repositories.dart';
import 'backup_codec.dart';
import 'backup_import.dart';

/// What opening a backup file found: either [errors] (nothing can be
/// imported) or a [plan] the person can review.
class ImportPreview {
  final BackupDecodeResult decoded;
  final ImportPlan? plan;

  /// Whether the phone already has any money units. Decides whether "also
  /// restore my settings" starts switched on (fresh phone) or off (there
  /// is something to lose).
  final bool phoneHasData;

  const ImportPreview({
    required this.decoded,
    required this.plan,
    required this.phoneHasData,
  });

  /// Every reason this file can't be imported, file problems first.
  List<String> get blockers => [
    ...decoded.errors,
    if (plan != null) ...plan!.problems,
  ];

  int get moreBlockers =>
      decoded.moreErrors + (plan == null ? 0 : plan!.moreProblems);

  bool get canImport => decoded.ok && plan != null && plan!.canApply;

  bool get hasSettings => plan?.incomingSettings != null;
}

/// What actually happened, for the "Done" message.
class ImportOutcome {
  final int added;
  final int replaced;
  final int skipped;
  final bool settingsRestored;

  const ImportOutcome({
    required this.added,
    required this.replaced,
    required this.skipped,
    required this.settingsRestored,
  });
}

class BackupService {
  BackupService(this._repo, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final BackupRepository _repo;
  final DateTime Function() _now;

  /// A friendly default file name, e.g. `fuata-backup-2026-09-30.json`.
  String suggestedFileName() {
    final d = _now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'fuata-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }

  Future<({String json, BackupSnapshot snapshot})> buildExport({
    bool includeRawText = false,
  }) async {
    final snapshot = await _repo.readAll();
    final json = BackupCodec.encode(
      snapshot,
      exportedAt: _now(),
      includeRawText: includeRawText,
    );
    return (json: json, snapshot: snapshot);
  }

  Future<ImportPreview> preview(String fileText) async {
    final decoded = BackupCodec.decode(fileText);
    final incoming = decoded.snapshot;
    final existing = await _repo.readAll();
    if (!decoded.ok || incoming == null) {
      return ImportPreview(
        decoded: decoded,
        plan: null,
        phoneHasData: existing.units.isNotEmpty,
      );
    }
    return ImportPreview(
      decoded: decoded,
      plan: ImportPlanner.plan(incoming: incoming, existing: existing),
      phoneHasData: existing.units.isNotEmpty,
    );
  }

  /// Applies [preview] under [policy]. Throws [StateError] if the preview
  /// was not importable — the screen never offers the button in that case,
  /// but this is the last line of defence against writing a bad file.
  Future<ImportOutcome> apply(
    ImportPreview preview, {
    required ConflictPolicy policy,
    required bool restoreSettings,
  }) async {
    final plan = preview.plan;
    if (!preview.canImport || plan == null) {
      throw StateError('This backup cannot be imported.');
    }
    final restore = restoreSettings ? plan.incomingSettings : null;
    await _repo.apply(plan.recordsToWrite(policy), settings: restore);

    final replaced = policy == ConflictPolicy.useFile ? plan.conflictCount : 0;
    return ImportOutcome(
      added: plan.addedCount,
      replaced: replaced,
      skipped: policy == ConflictPolicy.keepMine ? plan.conflictCount : 0,
      settingsRestored: restore != null,
    );
  }
}
