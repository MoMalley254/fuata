import '../models/limit_rule.dart';
import '../models/settings.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../models/unit.dart';

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
  Future<void> confirmTransaction(String transactionId);
  Future<void> deleteTransaction(String transactionId);
}

abstract class LimitRepository {
  Stream<List<LimitRule>> watchLimits();
  Future<void> setLimit(LimitRule limit);
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