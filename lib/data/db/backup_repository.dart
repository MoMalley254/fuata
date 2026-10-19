// ---------------------------------------------------------------------------
// Export/import storage (issue #24). Reads every table a backup carries,
// and writes an import in one transaction: either all of it lands or none
// of it does, so a failure half-way can never leave the ledger with some of
// a file's transactions but not others.
//
// Written against the same tables and mappers as drift_repositories.dart,
// so there is exactly one place that knows how each record is stored.
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';

import '../../domain/models/backup_snapshot.dart';
import '../../domain/models/settings.dart';
import '../../domain/repositories/repositories.dart';
import 'app_database.dart';
import 'drift_repositories.dart';
import 'mappers.dart';

class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db);
  final AppDatabase _db;

  @override
  Future<BackupSnapshot> readAll() async {
    // Every table is read in a fixed order, so the same data always
    // exports to the same file (and two exports can be compared).
    final categories = await (_db.select(_db.categories)..orderBy([
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.id),
    ])).get();
    final units =
        await (_db.select(_db.units)..orderBy([
              (u) => OrderingTerm(expression: u.sortOrder),
              (u) => OrderingTerm(expression: u.id),
            ]))
            .get();
    final sources = await (_db.select(
      _db.captureSources,
    )..orderBy([(s) => OrderingTerm(expression: s.id)])).get();
    final templates = await (_db.select(
      _db.templates,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
    final transactions =
        await (_db.select(_db.transactions)..orderBy([
              (t) => OrderingTerm(expression: t.occurredAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final limits = await (_db.select(
      _db.limitRules,
    )..orderBy([(l) => OrderingTerm(expression: l.id)])).get();
    final outings = await (_db.select(_db.outings)
      ..orderBy([(o) => OrderingTerm(expression: o.startAt),
            (o) => OrderingTerm(expression: o.id)]))
        .get();
    // Empty table (fresh install) yields AppSettings.defaults, which is
    // exactly what "the phone's current settings" means there.
    final settings = await DriftSettingsRepository(_db).watchSettings().first;

    return BackupSnapshot(
      categories: [
        for (final c in categories)
          BackupCategory(
            id: c.id,
            name: c.name,
            emoji: c.emoji,
            colorValue: c.colorValue,
            sortOrder: c.sortOrder,
            archived: c.archived,
          ),
      ],
      units: units.map(unitFromRow).toList(),
      captureSources: sources.map(captureSourceFromRow).toList(),
      templates: templates.map(templateFromRow).toList(),
      transactions: transactions.map(transactionFromRow).toList(),
      limits: limits.map(limitRuleFromRow).toList(),
      outings: outings.map(outingFromRow).toList(),
      settings: settings,
    );
  }

  @override
  Future<void> apply(BackupSnapshot records, {AppSettings? settings}) async {
    // #114: what the app-wide currency will be once this import is done.
    // If the file's settings are being restored, the file decides; if not,
    // the phone's own setting does. Read it *before* the transaction so
    // there's no re-entrant stream read inside one.
    final finalCurrency = settings?.currencyCode ??
        (await DriftSettingsRepository(_db).watchSettings().first)
        .currencyCode;

    return _db.transaction(() async {
      // Parents before children, so foreign keys hold at every step:
      // categories, units and apps first; then the rules that point at
      // units/apps; then transactions, which point at all of them.
      await _db.batch((b) {
        if (records.categories.isNotEmpty) {
          b.insertAllOnConflictUpdate(_db.categories, [
            for (final c in records.categories)
              CategoriesCompanion.insert(
                id: c.id,
                name: c.name,
                emoji: c.emoji,
                colorValue: c.colorValue,
                sortOrder: Value(c.sortOrder),
                archived: Value(c.archived),
              ),
          ]);
        }
        if (records.units.isNotEmpty) {
          b.insertAllOnConflictUpdate(
            _db.units,
            records.units.map(unitToCompanion).toList(),
          );
        }
        if (records.captureSources.isNotEmpty) {
          b.insertAllOnConflictUpdate(
            _db.captureSources,
            records.captureSources.map(captureSourceToCompanion).toList(),
          );
        }
        if (records.templates.isNotEmpty) {
          b.insertAllOnConflictUpdate(
            _db.templates,
            records.templates.map(templateToCompanion).toList(),
          );
        }
        if (records.transactions.isNotEmpty) {
          b.insertAllOnConflictUpdate(
            _db.transactions,
            records.transactions.map(transactionToCompanion).toList(),
          );
        }
      });

      if (records.outings.isNotEmpty) {
        await _db.batch((b) => b.insertAllOnConflictUpdate(
          _db.outings,
          records.outings.map(outingToCompanion).toList(),
        ));
      }

      // Limits go through the repository so a changed amount clears the
      // alerts already shown for the old one, exactly as editing does
      // (#63). Nested transactions become savepoints, so this stays part
      // of the same all-or-nothing unit.
      final limits = DriftLimitRepository(_db);
      for (final l in records.limits) {
        await limits.setLimit(l);
      }

      if (settings != null) {
        await DriftSettingsRepository(_db).updateSettings(settings);
      }

      // #114: every unit agrees with the app-wide currency. The per-unit
      // field is display state (see MoneyUnit.currencyCode's doc), so a
      // file from before #114 — or one whose units were hand-edited —
      // can't leave two different symbols on screen.
      await _db.update(_db.units).write(
        UnitsCompanion(currency: Value(finalCurrency)),
      );
    });
  }

  @override
  Future<void> eraseAll() {
    return _db.transaction(() async {
      // Children before parents, so the foreign keys hold at every step:
      // transactions reference units, categories and templates; templates
      // reference units and capture sources; limits reference units. The
      // alert log and unparsed captures have no foreign keys and could go
      // any time, but keeping one ordered list here means there is one
      // place to read what "everything" means.
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.templates).go();
      await _db.delete(_db.limitRules).go();
      await _db.delete(_db.alertFirings).go();
      await _db.delete(_db.outings).go();
      await _db.delete(_db.units).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.captureSources).go();
      await _db.delete(_db.unparsedCaptures).go();
      // Empty settings means "first install" to DriftSettingsRepository
      // (see _toSettings' rows.isEmpty branch), which is what brings
      // onboardingComplete back to false and sends the person through
      // onboarding. Deleting the rows is the whole reset; there is no
      // per-key write to forget.
      await _db.delete(_db.settingsEntries).go();
    });
  }
}
