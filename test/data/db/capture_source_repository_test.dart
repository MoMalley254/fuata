// Issue #22: the allow-list's storage. In-memory database, real repository.
//
// Needs code generation first: dart run build_runner build

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/models/capture_source.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  late AppDatabase db;
  late DriftCaptureSourceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCaptureSourceRepository(db);
  });

  tearDown(() => db.close());

  CaptureSource source(String pkg, String name, {bool enabled = true}) =>
      CaptureSource(
        id: CaptureSource.idFor(pkg),
        packageName: pkg,
        displayName: name,
        enabled: enabled,
      );

  test('saving the same package twice is one row (upsert by derived id)', () async {
    await repo.saveSource(source('com.example.messages', 'Messages'));
    await repo.saveSource(source('com.example.messages', 'Messages'));

    expect(await repo.watchSources().first, hasLength(1));
  });

  test('turning an app off keeps the row and flips enabled', () async {
    await repo.saveSource(source('com.example.messages', 'Messages'));
    await repo.saveSource(source('com.example.messages', 'Messages', enabled: false));

    final rows = await repo.watchSources().first;
    expect(rows, hasLength(1));
    expect(rows.single.enabled, isFalse);
  });

  test('sources come back ordered by display name', () async {
    await repo.saveSource(source('com.z', 'Zed bank'));
    await repo.saveSource(source('com.a', 'Alpha messages'));

    final names = (await repo.watchSources().first).map((s) => s.displayName);
    expect(names, ['Alpha messages', 'Zed bank']);
  });

  test('toggling a source a template points at does not break the foreign key', () async {
    await DriftUnitRepository(db).addUnit(
      MoneyUnit(
        id: 'u1',
        name: 'Mobile money',
        kind: UnitKind.mobileMoney,
        currencyCode: 'KES',
        iconEmoji: '📱',
        color: const Color(0xFF3D7FE0),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 21),
      ),
    );
    await repo.saveSource(source('com.example.messages', 'Messages'));
    await DriftTemplateRepository(db).saveTemplate(
      CaptureTemplate.fromLabeledSample(
        id: 't1',
        unitId: 'u1',
        captureSourceId: CaptureSource.idFor('com.example.messages'),
        name: 'paid',
        direction: TemplateDirection.spent,
        sampleText: 'Paid Ksh350.00',
        labels: const [
          LabeledSpan(start: 5, end: 14, type: TemplateFieldType.amount),
        ],
      ),
    );

    // Would throw a foreign-key error if this were delete-and-insert.
    await repo.saveSource(source('com.example.messages', 'Messages', enabled: false));

    expect((await repo.watchSources().first).single.enabled, isFalse);
  });
}
