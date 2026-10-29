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

import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:fuata/domain/models/template.dart';

import '../../domain/models/capture_source.dart';
import '../../domain/models/category.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/outing.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/unparsed_capture.dart';
import 'app_database.dart';

UnitKind _unitKindFromText(String s) => UnitKind.values.firstWhere(
  (e) => e.name == s,
  orElse: () => UnitKind.other,
);

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
    iconEmoji: row.iconValue,
    color: Color(row.colorValue),
    openingBalanceMinor: row.openingBalanceMinor,
    sortOrder: row.sortOrder,
    archived: row.archived,
    archivedAt: row.archivedAt,
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
    archivedAt: Value(unit.archivedAt),
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

// --- Outing (#30) --------------------------------------------------------

Outing outingFromRow(OutingRow row) => Outing(
  id: row.id,
  name: row.name,
  amountMinor: row.amountMinor,
  currencyCode: row.currency,
  // #30: drift stores DateTimes as epoch and returns them from the DB in
  // UTC on read. Everything this app *displays* — "ends Fri 20 Oct",
  // "starts Mon 15" — is in the person's local time, and every outings
  // test constructs local DateTimes. Convert on the way out, so the
  // model is always local and callers never have to reason about it.
  startAt: row.startAt.toLocal(),
  endAt: row.endAt.toLocal(),
  unitIds: row.unitIds.isEmpty
      ? const <String>{}
      : row.unitIds.split(',').toSet(),
  bannerEnabled: row.bannerEnabled,
  enabled: row.enabled,
  createdAt: row.createdAt.toLocal(),
);

OutingsCompanion outingToCompanion(Outing o) => OutingsCompanion.insert(
  id: o.id,
  name: o.name,
  amountMinor: o.amountMinor,
  currency: o.currencyCode,
  startAt: o.startAt,
  endAt: o.endAt,
  unitIds: Value(o.unitIds.join(',')),
  bannerEnabled: Value(o.bannerEnabled),
  enabled: Value(o.enabled),
  createdAt: o.createdAt,
);

// --- Template ------------------------------------------------------------

/// The row carries exactly the keys [CaptureTemplate.fromJson] expects —
/// only `fieldMap` is stored on disk as JSON text (tables.dart's
/// `fieldMapJson` column), so decode that one before handing over.
CaptureTemplate templateFromRow(TemplateRow row) {
  return CaptureTemplate.fromJson({
    'id': row.id,
    'unitId': row.unitId,
    'captureSourceId': row.captureSourceId,
    'name': row.name,
    'direction': row.direction,
    'pattern': row.pattern,
    'fieldMap': jsonDecode(row.fieldMapJson),
    'sampleText': row.sampleText,
    'version': row.version,
    'enabled': row.enabled,
    'customFieldNames': jsonDecode(row.customFieldNamesJson),
  });
}

TemplatesCompanion templateToCompanion(CaptureTemplate t) {
  return TemplatesCompanion.insert(
    id: t.id,
    unitId: t.unitId,
    captureSourceId: Value(t.captureSourceId),
    name: t.name,
    direction: Value(t.direction.name),
    pattern: t.pattern,
    fieldMapJson: jsonEncode(
      t.fieldMap.map((groupName, type) => MapEntry(groupName, type.name)),
    ),
    sampleText: t.sampleText,
    version: Value(t.version),
    enabled: Value(t.enabled),
    customFieldNamesJson: Value(jsonEncode(t.customFieldNames)),
  );
}

// --- UnparsedCapture -------------------------------------------------------

/// Straight pass-through — the row and the domain model have exactly the
/// same four fields (tables.dart's UnparsedCaptures).
UnparsedCapture unparsedCaptureFromRow(UnparsedCaptureRow row) {
  return UnparsedCapture(
    id: row.id,
    receivedAt: row.receivedAt,
    sourcePackage: row.sourcePackage,
    rawText: row.rawText,
  );
}
// --- CaptureSource ---------------------------------------------------------

CaptureSource captureSourceFromRow(CaptureSourceRow row) {
  return CaptureSource(
    id: row.id,
    packageName: row.packageName,
    displayName: row.displayName,
    enabled: row.enabled,
  );
}

CaptureSourcesCompanion captureSourceToCompanion(CaptureSource s) {
  return CaptureSourcesCompanion.insert(
    id: s.id,
    packageName: s.packageName,
    displayName: s.displayName,
    enabled: Value(s.enabled),
  );
}

// --- Category ------------------------------------------------------------

Category categoryFromRow(CategoryRow row) {
  return Category(
    id: row.id,
    name: row.name,
    emoji: row.emoji,
    color: Color(row.colorValue),
    sortOrder: row.sortOrder,
    archived: row.archived,
  );
}

CategoriesCompanion categoryToCompanion(Category c) {
  return CategoriesCompanion.insert(
    id: c.id,
    name: c.name,
    emoji: c.emoji,
    colorValue: c.color.toARGB32(),
    sortOrder: Value(c.sortOrder),
    archived: Value(c.archived),
  );
}
