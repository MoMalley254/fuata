import '../models/backup_snapshot.dart';
import '../models/capture_source.dart';
import '../models/limit_alert.dart';
import '../models/limit_rule.dart';
import '../models/settings.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../models/unit.dart';
import '../models/unparsed_capture.dart';

/// Screens depend only on these interfaces (design.md, "UI-first approach").
/// Two implementations exist: MockUnitRepository etc. (data/mock, used by
/// widget tests/previews) and Drift*Repository (data/db, wired up by
/// default in app_providers.dart as of #13) — swapped via Riverpod
/// provider overrides, with no screen changes needed either way.
abstract class UnitRepository {
  Stream<List<MoneyUnit>> watchUnits({bool includeArchived = false});
  Future<void> addUnit(MoneyUnit unit);
  Future<void> updateUnit(MoneyUnit unit);

  /// Sets [archived] true and stamps [archivedAt] with the current time.
  Future<void> archiveUnit(String unitId);

  /// Clears [archived] and [archivedAt]. The unit's sortOrder is untouched,
  /// so a restored unit comes back to the same place in the list it left
  /// from (finding F9's "restored units keep their sort position").
  Future<void> unarchiveUnit(String unitId);
}

abstract class TransactionRepository {
  Stream<List<MoneyTransaction>> watchTransactions({String? unitId});
  Future<void> addTransaction(MoneyTransaction transaction);
  // In-place edit of an existing row (the review inbox's Fix, #21).
  // Drift implements it as an upsert by primary key; the mock replaces
  // the stored item with the same id.
  Future<void> updateTransaction(MoneyTransaction transaction);
  Future<void> confirmTransaction(String transactionId);
  Future<void> deleteTransaction(String transactionId);
}

abstract class LimitRepository {
  Stream<List<LimitRule>> watchLimits();
  Future<void> setLimit(LimitRule limit);
  Future<void> deleteLimit(String limitId);
}

/// Personalisation settings (design.md's `settings` key/value table).
/// One object in, one object out — same reasoning as the other
/// repositories: screens never see how it's stored.
abstract class SettingsRepository {
  Stream<AppSettings> watchSettings();
  Future<void> updateSettings(AppSettings settings);
}

/// Capture templates (design.md TEMPLATE, ADR-007): built by the rule
/// builder (#20) from a pasted sample plus user-labeled spans, consumed
/// by the parser whenever a message is matched (#21/#22). The Templates
/// drift table has existed since #13; this interface is the seam the
/// rule builder talks through so it never learns that drift exists.
abstract class TemplateRepository {
  Stream<List<CaptureTemplate>> watchTemplates({String? unitId});
  Future<void> saveTemplate(CaptureTemplate template);
  Future<void> deleteTemplate(String templateId);
}

/// Unparsed captures (design.md's `unparsed_capture` table): messages
/// nothing could read, kept for the review inbox's "Couldn't read these"
/// list (US-11) and auto-purged after 7 days. #21 writes these from the
/// share/paste paths; #22's notification listener writes the same table.
abstract class CaptureRepository {
  Stream<List<UnparsedCapture>> watchUnparsed();
  Future<void> recordUnparsed({
    required String id,
    required String sourcePackage,
    required String rawText,
  });
  Future<void> deleteUnparsed(String captureId);
}

/// The notification allow-list (design.md CAPTURE_SOURCE, US-10): which
/// apps Fuata may read notifications from. Enabled rows *are* the
/// allow-list. There is deliberately no delete: turning an app off flips
/// `enabled`, because templates reference this table (see
/// [CaptureSource]).
abstract class CaptureSourceRepository {
  Stream<List<CaptureSource>> watchSources();

  /// Upsert by id — use [CaptureSource.idFor] so one package is one row.
  Future<void> saveSource(CaptureSource source);
}

/// Which limit alerts have already been shown (issue #63, US-06: "fires
/// once per threshold per period"). Lives in the database, not memory,
/// because two isolates raise alerts and the answer has to survive the
/// app being killed.
abstract class AlertLogRepository {
  Future<Set<AlertKey>> firedKeys();

  /// Atomically records [key] as shown. True for exactly one caller ever;
  /// false if it was already claimed (by anyone, including another
  /// isolate) or could not be recorded — in both cases: do not show it.
  Future<bool> claim(AlertKey key, DateTime at);

  Future<void> purgeBefore(DateTime cutoff);
}

/// Whole-database access for export/import (issue #24). Unlike the other
/// repositories this one is not a stream for a screen to watch: it is read
/// once when exporting or planning an import, and written once — in a
/// single transaction — when the person confirms.
abstract class BackupRepository {
  /// Everything a backup carries, including current settings.
  Future<BackupSnapshot> readAll();

  /// Writes [records] (upserting by id) and, when [settings] is given,
  /// replaces the settings — all or nothing. Callers decide *what* to
  /// write (see ImportPlan.recordsToWrite); this never decides to
  /// overwrite anything on its own.
  Future<void> apply(BackupSnapshot records, {AppSettings? settings});

  /// Wipes everything Fuata has stored on this phone (US-16's "Erase
  /// everything", issue #85): every record table, the alert log and the
  /// settings, in one transaction.
  ///
  /// Saved backup *files* are deliberately not touched — they live wherever
  /// the person put them, and Fuata has no list of where (ADR-011).
  ///
  /// This can only reach the database. The caller also has to cancel the
  /// posted banner, clear the native allow-list mirror and clear the
  /// home-widget snapshot — see [DriftBackupRepository.eraseAll]'s callers.
  Future<void> eraseAll();
}
