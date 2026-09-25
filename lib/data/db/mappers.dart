// ---------------------------------------------------------------------------
// Domain <-> drift-row conversions, kept in one place so the repository
// classes in drift_repositories.dart read as plain CRUD/streams and none
// of them duplicate this mapping logic.
//
// Enums are stored as their `.name` string rather than an int index —
// reordering an enum's cases (or drift's own EnumIndexConverter) can
// silently reinterpret old rows as the wrong value; a name string can't.
// ---------------------------------------------------------------------------

// --- enum <-> text -----------------------------------------------------

import 'dart:ui';

import 'package:drift/drift.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import 'app_database.dart';

UnitKind _unitKindFromText(String s) =>
    UnitKind.values.firstWhere((e) => e.name == s, orElse: () => UnitKind.other);

TxType _txTypeFromText(String s) =>
    TxType.values.firstWhere((e) => e.name == s, orElse: () => TxType.spent);

TxSource _txSourceFromText(String s) => TxSource.values.firstWhere(
      (e) => e.name == s,
  orElse: () => TxSource.manual,
);

TxStatus _txStatusFromText(String s) => TxStatus.values.firstWhere(
      (e) => e.name == s,
  orElse: () => TxStatus.confirmed,
);

LimitScope _limitScopeFromText(String s) => LimitScope.values.firstWhere(
      (e) => e.name == s,
  orElse: () => LimitScope.overall,
);

LimitPeriod _limitPeriodFromText(String s) => LimitPeriod.values.firstWhere(
      (e) => e.name == s,
  orElse: () => LimitPeriod.day,
);

// --- Unit ----------------------------------------------------------------

MoneyUnit unitFromRow(UnitRow row) {
  return MoneyUnit(
    id: row.id,
    name: row.name,
    kind: _unitKindFromText(row.kind),
    currencyCode: row.currency,
    // v0.1 only ever writes iconType == 'emoji' (see tables.dart); any
    // other value falls back to the raw stored value rather than crashing.
    iconEmoji: row.iconValue,
    color: Color(row.colorValue),
    openingBalanceMinor: row.openingBalanceMinor,
    sortOrder: row.sortOrder,
    archived: row.archived,
    lastVerifiedAt: row.lastVerifiedAt,
    createdAt: row.createdAt,
  );
}

UnitsCompanion unitToCompanion(MoneyUnit unit) {
  return UnitsCompanion.insert(
    id: unit.id,
    name: unit.name,
    kind: unit.kind.name,
    currency: unit.currencyCode,
    iconType: const Value('emoji'),
    iconValue: unit.iconEmoji,
    colorValue: unit.color.toARGB32(),
    openingBalanceMinor: Value(unit.openingBalanceMinor),
    sortOrder: Value(unit.sortOrder),
    archived: Value(unit.archived),
    lastVerifiedAt: Value(unit.lastVerifiedAt),
    createdAt: unit.createdAt,
  );
}

// --- Transaction -----------------------------------------------------------

MoneyTransaction transactionFromRow(TransactionRow row) {
  return MoneyTransaction(
    id: row.id,
    unitId: row.unitId,
    type: _txTypeFromText(row.type),
    amountMinor: row.amountMinor,
    counterparty: row.counterparty,
    categoryId: row.categoryId,
    note: row.note,
    code: row.code,
    occurredAt: row.occurredAt,
    createdAt: row.createdAt,
    source: _txSourceFromText(row.source),
    status: _txStatusFromText(row.status),
    transferGroupId: row.transferGroupId,
    parentId: row.parentId,
    templateId: row.templateId,
    balanceAfterMinor: row.balanceAfterMinor,
    rawText: row.rawText,
  );
}

TransactionsCompanion transactionToCompanion(MoneyTransaction t) {
  return TransactionsCompanion.insert(
    id: t.id,
    unitId: t.unitId,
    type: t.type.name,
    amountMinor: t.amountMinor,
    counterparty: Value(t.counterparty),
    categoryId: Value(t.categoryId),
    note: Value(t.note),
    code: Value(t.code),
    occurredAt: t.occurredAt,
    createdAt: t.createdAt,
    source: t.source.name,
    status: t.status.name,
    transferGroupId: Value(t.transferGroupId),
    parentId: Value(t.parentId),
    templateId: Value(t.templateId),
    balanceAfterMinor: Value(t.balanceAfterMinor),
    rawText: Value(t.rawText),
  );
}

// --- LimitRule ---------------------------------------------------------

LimitRule limitRuleFromRow(LimitRuleRow row) {
  return LimitRule(
    id: row.id,
    scope: _limitScopeFromText(row.scope),
    unitId: row.unitId,
    period: _limitPeriodFromText(row.period),
    amountMinor: row.amountMinor,
    currencyCode: row.currency,
    warnAt: row.warnAt,
    dangerAt: row.dangerAt,
    enabled: row.enabled,
  );
}

LimitRulesCompanion limitRuleToCompanion(LimitRule l) {
  return LimitRulesCompanion.insert(
    id: l.id,
    scope: l.scope.name,
    unitId: Value(l.unitId),
    period: l.period.name,
    amountMinor: l.amountMinor,
    currency: l.currencyCode,
    warnAt: Value(l.warnAt),
    dangerAt: Value(l.dangerAt),
    enabled: Value(l.enabled),
  );
}
