// Issue #83: the categories repository against an in-memory database.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/models/category.dart';

void main() {
  late AppDatabase db;
  late DriftCategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCategoryRepository(db);
  });

  tearDown(() => db.close());

  test('the default set is seeded once, on create', () async {
    final cats = await repo.watchCategories().first;
    expect(cats, isNotEmpty);
    expect(cats.first.name, 'Food');
    expect(cats.map((c) => c.name), containsAll(['Food', 'Transport', 'Other']));
  });

  test('adding a category puts it at the end', () async {
    final before = await repo.watchCategories().first;
    final next = before.length;
    await repo.saveCategory(Category(
      id: 'cat_test',
      name: 'Coffee',
      emoji: '☕',
      color: const Color(0xFFE07A5F),
      sortOrder: next,
    ));
    final after = await repo.watchCategories().first;
    expect(after.last.name, 'Coffee');
  });

  test('saving an existing id updates in place', () async {
    final first = (await repo.watchCategories().first).first;
    await repo.saveCategory(first.copyWith(name: 'Groceries'));
    final after = await repo.watchCategories().first;
    expect(after.where((c) => c.id == first.id).single.name, 'Groceries');
  });

  test('archiving hides a category from the picker but not the settings screen',
          () async {
        final first = (await repo.watchCategories().first).first;
        await repo.archiveCategory(first.id);

        expect(await repo.watchCategories().first, hasLength(8));
        final all = await repo.watchCategoriesIncludingArchived().first;
        expect(all, hasLength(9));
        expect(all.firstWhere((c) => c.id == first.id).archived, isTrue);
      });

  test('unarchiving brings it back', () async {
    final first = (await repo.watchCategories().first).first;
    await repo.archiveCategory(first.id);
    await repo.unarchiveCategory(first.id);
    expect(await repo.watchCategories().first, hasLength(9));
  });
}