import '../models/limit_rule.dart';
import '../models/transaction.dart';
import '../models/unit.dart';

/// Screens depend only on these interfaces (design.md, "UI-first approach").
/// Today: MockUnitRepository etc. Later (#13): drift-backed implementations,
/// swapped in via Riverpod provider overrides — no screen changes needed.
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