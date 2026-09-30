// Issue #24: deciding what an import would do. Pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/backup_import.dart';
import 'package:fuata/domain/models/backup_snapshot.dart';
import 'package:fuata/domain/models/transaction.dart';

import 'backup_test_data.dart';

void main() {
  ImportPlan plan(BackupSnapshot incoming, [BackupSnapshot? existing]) =>
      ImportPlanner.plan(
        incoming: incoming,
        existing: existing ?? BackupSnapshot.empty,
      );

  test('into an empty phone, everything is new', () {
    final p = plan(fullSnapshot());

    expect(p.canApply, isTrue);
    expect(p.units.added, hasLength(2));
    expect(p.transactions.added, hasLength(2));
    expect(p.templates.added, hasLength(1));
    expect(p.limits.added, hasLength(2));
    expect(p.categories.added, hasLength(1));
    expect(p.captureSources.added, hasLength(1));
    expect(p.hasConflicts, isFalse);
    expect(p.identicalCount, 0);
    expect(p.addedCount, fullSnapshot().recordCount);
  });

  test('importing what is already here changes nothing', () {
    final p = plan(fullSnapshot(), fullSnapshot());

    expect(p.addedCount, 0);
    expect(p.conflictCount, 0);
    expect(p.identicalCount, fullSnapshot().recordCount);
    expect(p.changesNothing, isTrue);
  });

  test('same id, different content is a conflict — not added, not identical', () {
    final incoming = BackupSnapshot(units: [unit('u1', name: 'Wallet')]);
    final existing = BackupSnapshot(units: [unit('u1', name: 'Cash')]);

    final p = plan(incoming, existing);

    expect(p.units.added, isEmpty);
    expect(p.units.conflicts, hasLength(1));
    expect(p.units.conflicts.single.existing.name, 'Cash');
    expect(p.units.conflicts.single.incoming.name, 'Wallet');
    expect(p.conflictCount, 1);
    expect(p.changesNothing, isFalse);
  });

  group('recordsToWrite', () {
    final incoming = BackupSnapshot(
      units: [unit('u1', name: 'Wallet'), unit('u2', name: 'New one')],
    );
    final existing = BackupSnapshot(units: [unit('u1', name: 'Cash')]);

    test('keepMine writes only the new records', () {
      final w = plan(incoming, existing).recordsToWrite(ConflictPolicy.keepMine);
      expect(w.units.map((u) => u.id), ['u2']);
    });

    test('useFile also writes the file\'s side of each conflict', () {
      final w = plan(incoming, existing).recordsToWrite(ConflictPolicy.useFile);
      expect(w.units.map((u) => u.id).toSet(), {'u1', 'u2'});
      expect(w.units.firstWhere((u) => u.id == 'u1').name, 'Wallet');
    });

    test('never includes settings', () {
      final w = plan(fullSnapshot()).recordsToWrite(ConflictPolicy.useFile);
      expect(w.settings, isNull);
    });
  });

  group('original message text', () {
    test('a file without it is not "different" from a phone that kept it', () {
      final existing = BackupSnapshot(
        units: [unit('u1')],
        transactions: [tx('t1', raw: 'kept in full')],
      );
      final incoming = BackupSnapshot(
        units: [unit('u1')],
        transactions: [tx('t1')],
      );

      final p = plan(incoming, existing);

      expect(p.transactions.conflicts, isEmpty);
      expect(p.transactions.identicalCount, 1);
    });

    test('replacing a transaction keeps the text the phone already had', () {
      final existing = BackupSnapshot(
        units: [unit('u1')],
        transactions: [tx('t1', raw: 'kept in full')],
      );
      final incoming = BackupSnapshot(
        units: [unit('u1')],
        transactions: [tx('t1', amount: -99900)],
      );

      final p = plan(incoming, existing);
      final written = p.recordsToWrite(ConflictPolicy.useFile).transactions.single;

      expect(p.transactions.conflicts, hasLength(1));
      expect(written.amountMinor, -99900);
      expect(written.rawText, 'kept in full');
    });
  });

  group('references', () {
    test('a transaction for a unit found nowhere blocks the import', () {
      final p = plan(BackupSnapshot(transactions: [tx('t1', unitId: 'ghost')]));

      expect(p.canApply, isFalse);
      expect(p.problems.single, contains('money unit'));
    });

    test('...but a unit already on the phone satisfies it (partial backup)', () {
      final p = plan(
        BackupSnapshot(transactions: [tx('t1', unitId: 'u1')]),
        BackupSnapshot(units: [unit('u1')]),
      );
      expect(p.canApply, isTrue);
    });

    test('a unit in the same file satisfies it', () {
      final p = plan(
        BackupSnapshot(units: [unit('u1')], transactions: [tx('t1')]),
      );
      expect(p.canApply, isTrue);
    });

    test('a rule pointing at a missing app blocks the import', () {
      final p = plan(
        BackupSnapshot(units: [unit('u1')], templates: [template()]),
      );
      expect(p.canApply, isFalse);
      expect(p.problems.single, contains('app'));
    });

    test('a per-unit limit for a missing unit blocks the import', () {
      final p = plan(BackupSnapshot(limits: [unitWeekLimit('ghost')]));
      expect(p.canApply, isFalse);
    });

    test('a transaction pointing at a missing category blocks the import', () {
      final withCategory = MoneyTransaction(
        id: 't1',
        unitId: 'u1',
        type: TxType.spent,
        amountMinor: -100,
        categoryId: 'nope',
        occurredAt: DateTime.utc(2026, 9, 20),
        createdAt: DateTime.utc(2026, 9, 20),
      );
      final p = plan(
        BackupSnapshot(units: [unit('u1')], transactions: [withCategory]),
      );

      expect(p.canApply, isFalse);
      expect(p.problems.single, contains('category'));
    });

    test('lists at most 20 problems and counts the rest', () {
      final p = plan(
        BackupSnapshot(
          transactions: [for (var i = 0; i < 50; i++) tx('t$i', unitId: 'ghost')],
        ),
      );
      expect(p.problems, hasLength(20));
      expect(p.moreProblems, 30);
    });
  });

  test('carries the file\'s settings without applying them', () {
    final p = plan(fullSnapshot());
    expect(p.incomingSettings!.name, 'Wanjiru');
  });
}