// ---------------------------------------------------------------------------
// Drift table definitions. These mirror docs/design.md section 2 (the ER
// diagram) as closely as SQLite allows.
//
// Scope note (issue #13): schemas exist here for every entity in the ER
// diagram, since Transaction/Template/LimitRule all reference the others
// by id and it's cheaper to shape the tables right once than to migrate
// twice. Repository *implementations* (the classes screens actually talk
// to) are only built for what the UI already depends on today: Unit,
// Transaction, LimitRule and Settings (see repositories.dart). Category,
// Template, CaptureSource and UnparsedCapture get their own repositories
// in the issues that build the features that use them (#19-#22).
//
// Every generated data class is renamed with @DataClassName to avoid
// colliding with the domain models of (almost) the same name — drift's
// default naming would otherwise generate a `LimitRule` class fighting
// with domain/models/limit_rule.dart's `LimitRule`, and similarly for
// `Unit`/`Transaction`. The suffix "Row" makes it visually obvious at the
// call site that you're holding a raw DB row, not a domain object.
// ---------------------------------------------------------------------------


import 'package:drift/drift.dart';

/// design.md UNIT. `iconType`/`iconValue` are split out per the ER diagram
/// even though MoneyUnit (v0.1) only ever populates 'emoji' — this is
/// where photo/icon-pack support (mentioned in the UI brief) lands later
/// without a schema change.
@DataClassName('UnitRow')
class Units extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get currency => text()();
  TextColumn get iconType => text().withDefault(const Constant('emoji'))();
  TextColumn get iconValue => text()();
  IntColumn get colorValue => integer()();
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastVerifiedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();
// When the unit was archived, so the Archived screen can say "Archived
// on 15 Oct". Nullable: an existing archived unit has no date, and an
// unarchived one has no reason to carry a stale one.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get colorValue => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// design.md CAPTURE_SOURCE. Populated by the capture work in #19-#22.
@DataClassName('CaptureSourceRow')
class CaptureSources extends Table {
  TextColumn get id => text()();
  TextColumn get packageName => text()();
  TextColumn get displayName => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// design.md TEMPLATE. Populated by the rule builder (#20).
@DataClassName('TemplateRow')
class Templates extends Table {
  TextColumn get id => text()();
  TextColumn get unitId => text().references(Units, #id)();
  TextColumn get captureSourceId =>
      text().nullable().references(CaptureSources, #id)();
  TextColumn get name => text()();
  // 'spent' | 'got' | 'either' — 'either' lets the message decide, per
  // ui-design-brief.md 7.7 step 4 ("or let the message decide").
  TextColumn get direction => text().withDefault(const Constant('either'))();
  TextColumn get pattern => text()();
  TextColumn get fieldMapJson => text()();
  TextColumn get sampleText => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// design.md TRANSACTION. amountMinor is the signed effect on the unit's
/// balance (ADR-004); moved rows share transferGroupId (ADR-005); a fee
/// is its own spent row with parentId pointing at the parent transaction.
@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get unitId => text().references(Units, #id)();
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get counterparty => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  TextColumn get code => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get source => text()();
  TextColumn get status => text()();
  TextColumn get transferGroupId => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get templateId => text().nullable().references(Templates, #id)();
  IntColumn get balanceAfterMinor => integer().nullable()();
  // Raw captured message text. Null by default — only kept if the user
  // opts in (ADR-009 / requirements.md non-functional "Privacy" row).
  TextColumn get rawText => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// design.md LIMIT_RULE.
@DataClassName('LimitRuleRow')
class LimitRules extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get unitId => text().nullable().references(Units, #id)();
  TextColumn get period => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  RealColumn get warnAt => real().withDefault(const Constant(0.7))();
  RealColumn get dangerAt => real().withDefault(const Constant(0.9))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Which limit alerts have been shown (issue #63, US-06: once per
/// threshold per period). The primary key *is* the "once" guarantee: a
/// second insert for the same (limit, period, level) fails, so two
/// isolates racing to announce the same crossing cannot both win.
///
/// No foreign key to LimitRules on purpose — DriftLimitRepository clears a
/// limit's rows itself when its amount changes or it is removed, and a
/// stale row must never block that delete.
@DataClassName('AlertFiringRow')
class AlertFirings extends Table {
  TextColumn get limitId => text()();
  TextColumn get periodKey => text()();
  TextColumn get level => text()();
  DateTimeColumn get firedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {limitId, periodKey, level};
}

/// design.md's "supporting tables (not drawn)": unparsed_capture, kept
/// only long enough for the review inbox's "Couldn't read these" list
/// before being auto-purged (US-11, requirements.md).
@DataClassName('UnparsedCaptureRow')
class UnparsedCaptures extends Table {
  TextColumn get id => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get sourcePackage => text()();
  TextColumn get rawText => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// design.md's `settings` key/value table. Kept as loose key/value rather
/// than typed columns so adding one more personalisation toggle (there
/// will be more — see ui-design-brief.md section 3) never needs a
/// migration; DriftSettingsRepository owns the mapping to/from AppSettings.
@DataClassName('SettingsEntryRow')
class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}