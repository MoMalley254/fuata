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
  /// definition in place. v0.1.0 ships at 1.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Example for the next schema change:
      // if (from < 2) {
      //   await m.addColumn(units, units.someNewColumn);
      // }
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite; the ER diagram in
      // design.md is only meaningful if they're actually enforced.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Android is the only target in v0.1 (requirements.md, non-goals).
    // Required so drift can find a working sqlite3 native library
    // instead of relying on the OS's own (often older) copy.
    // if (Platform.isAndroid) {
    //   await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    // }

    // Unencrypted SQLite in v0.1 (ADR-010, time-boxed decision).
    // SQLCipher + Android Keystore is planned for v1.1, at which point
    // this is where the cipher key gets wired in.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fuata.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
