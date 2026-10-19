// ---------------------------------------------------------------------------
// The database itself: one file on disk, opened lazily, with foreign keys
// enforced and a migration strategy that has room to grow.
//
// This file needs code generation before it will compile:
//   dart run build_runner build --delete-conflicting-outputs
// which produces app_database.g.dart (the `_$AppDatabase` base class).
// That generated file is intentionally not checked in by hand here — it's
// build output, same as any other `.g.dart` file in this project.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/category.dart';
import 'db_key.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Units,
    Transactions,
    Categories,
    LimitRules,
    Templates,
    CaptureSources,
    UnparsedCaptures,
    SettingsEntries,
    AlertFirings,
    Outings, //#30
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an [executor] in tests (e.g. `NativeDatabase.memory()`); the app
  /// itself uses the default, which opens (or creates) `fuata.sqlite` in
  /// app-private storage — never a shared/external directory, per
  /// ADR-009/US-16 (nothing leaves, or is even reachable outside, the app).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Bump this whenever a table shape changes, and add a step to
  /// [migration]'s `onUpgrade` — never edit a shipped version's table
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultCategories();
    },
    onUpgrade: (m, from, to) async {
      // (#63): the limit-alert log. Additive only — no existing table
      // changes, so nobody's data is touched.
      // if (from < 2) {
      //   await m.createTable(alertFirings);
      // }
      //Intentionally no schema update still in development no rollout and need for schema update
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite; the ER diagram in
      // design.md is only meaningful if they're actually enforced.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Inserts the default set if — and only if — the categories table is
  /// empty. Called from onCreate safe to call again
  /// anywhere.
  ///
  /// Deliberately NOT `batch(...)`: drift's batch is lazy, and inside
  /// `onCreate` the queued inserts would flush *after* the migration
  /// callback returned. A test that then cleared the table on the very
  /// next query saw 9 stale rows appear underneath it, because the batch
  /// landed between the clear and the fixture's insert. Individual
  /// awaited inserts complete before `ensureOpen` lets any user query
  /// through, which is the whole point of running this from `onCreate`.
  Future<void> _seedDefaultCategories() async {
    final existing = await (select(categories)..limit(1)).get();
    if (existing.isNotEmpty) return;
    for (final c in defaultCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: c.id,
          name: c.name,
          emoji: c.emoji,
          colorValue: c.color.toARGB32(),
          sortOrder: Value(c.sortOrder),
          archived: Value(c.archived),
        ),
      );
    }
  }

}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Unencrypted SQLite in v0.1 (ADR-010, time-boxed decision).
    // SQLCipher + Android Keystore is planned for v1.1, at which point
    // this is where the cipher key gets wired in.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fuata.sqlite'));

    // #28: the key is read from Android Keystore on every open. It is not
    // cached in memory beyond the process lifetime, and never written
    // anywhere else.
    final key = await DbKey.getOrCreate();

    return NativeDatabase.createInBackground(
        file,
      setup: (rawDb) {
        // `x'...'` tells SQLCipher this is a raw hex key, not a passphrase
        // to run through PBKDF2. Raw keys are faster and unambiguous.
        rawDb.execute("PRAGMA key = \"x'$key'\";");
        // Verify the key is correct now, rather than on the first query.
        rawDb.execute('SELECT count(*) FROM sqlite_master;');
      }
    );
  });
}