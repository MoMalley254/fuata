// The onboarding flag (issue #7) and how it is stored: a fresh install is
// "not onboarded", an install from before #7 is not sent back through it,
// and a backup restore never re-triggers it.
//
// Needs code generation first: dart run build_runner build

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/models/settings.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSettingsRepository(db);
  });

  tearDown(() => db.close());

  test('a fresh install has not been through onboarding', () async {
    expect((await repo.watchSettings().first).onboardingComplete, isFalse);
  });

  test('finishing onboarding is remembered', () async {
    await repo.updateSettings(
      AppSettings.defaults.copyWith(onboardingComplete: true),
    );
    expect((await repo.watchSettings().first).onboardingComplete, isTrue);
  });

  test('saving other settings mid-onboarding does not finish it', () async {
    // The accent is written as soon as it is picked, before the end.
    await repo.updateSettings(
      AppSettings.defaults.copyWith(accent: AppAccents.coral),
    );
    final s = await repo.watchSettings().first;
    expect(s.accent, AppAccents.coral);
    expect(s.onboardingComplete, isFalse);
  });

  test('settings saved before #7 (no flag) count as already onboarded', () async {
    await db.into(db.settingsEntries).insert(
      SettingsEntriesCompanion.insert(key: 'name', value: 'Wanjiru'),
    );
    final s = await repo.watchSettings().first;
    expect(s.name, 'Wanjiru');
    expect(s.onboardingComplete, isTrue);
  });

  test('a skipped (empty) name survives a round trip', () async {
    await repo.updateSettings(
      AppSettings.defaults.copyWith(name: '', onboardingComplete: true),
    );
    expect((await repo.watchSettings().first).name, '');
  });
}
