import '../models/capture_source.dart';
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
  Future<void> archiveUnit(String unitId);
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
