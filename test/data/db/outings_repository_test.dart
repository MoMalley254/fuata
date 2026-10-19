import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/models/outing.dart';

void main() {
  late AppDatabase db;
  late DriftOutingRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftOutingRepository(db);
  });
  tearDown(() => db.close());

  Outing outing(String id, {String name = 'Trip'}) => Outing(
    id: id,
    name: name,
    amountMinor: 150000,
    currencyCode: 'KES',
    startAt: DateTime(2026, 10, 15),
    endAt: DateTime(2026, 10, 20),
    createdAt: DateTime(2026, 10, 1),
  );

  test('round-trips through the repository', () async {
    await repo.saveOuting(outing('o1', name: 'Mombasa'));
    final outings = await repo.watchOutings().first;
    expect(outings.single.name, 'Mombasa');
    expect(outings.single.amountMinor, 150000);
    expect(outings.single.startAt, DateTime(2026, 10, 15));
  });

  test('round-trips unitIds', () async {
    await repo.saveOuting(outing('o1').copyWith(unitIds: {'cash', 'mpesa'}));
    final outings = await repo.watchOutings().first;
    expect(outings.single.unitIds, {'cash', 'mpesa'});
  });

  test('endOutingNow ends it early and stamps endAt', () async {
    final original = outing('o1');   // endAt = 2026-10-20
    await repo.saveOuting(original);

    final before = DateTime.now();
    await repo.endOutingNow('o1');
    final after = DateTime.now();

    final o = (await repo.watchOutings().first).single;

    expect(o.enabled, isFalse,
        reason: 'endOutingNow must set enabled=false');

    // Meaningful assertion: endAt moved to something earlier than the
    // original 2026-10-20. This is the one that catches the original bug
    // (endAt never written at all).
    expect(o.endAt.isBefore(original.endAt), isTrue,
        reason: 'endAt must move back from ${original.endAt}');

    // Sanity belt: endAt is approximately "now", not some arbitrary past
    // value. Drift's dateTime() column stores Unix seconds, so the write
    // truncates sub-second precision — a `before = ...147ms` and a write
    // at `...312ms` both land in the DB as `...000s`. Comparing against
    // a ±2-second window is what makes this test immune to that, and to
    // wall-clock precision on any host.
    final tolerance = const Duration(seconds: 2);
    expect(o.endAt.isAfter(before.subtract(tolerance)), isTrue,
        reason: 'endAt ($before) is earlier than "${before}" minus the '
            'tolerance — endOutingNow did not use a recent timestamp');
    expect(o.endAt.isBefore(after.add(tolerance)), isTrue,
        reason: 'endAt is later than "${after}" plus the tolerance — '
            'endOutingNow wrote a value from the future');

    // Belt-and-braces: whatever the truncation did, the new endAt is
    // within a couple of seconds of where `after` sat, so the person's
    // "I came home just now" experience is preserved.
    final delta = after.difference(o.endAt).inSeconds.abs();
    expect(delta <= 2, isTrue,
        reason: 'endAt should be within 2 seconds of "now" — got '
            '${o.endAt}, delta ${delta}s');
  });

  test('saveOuting upserts by id', () async {
    await repo.saveOuting(outing('o1', name: 'A'));
    await repo.saveOuting(outing('o1', name: 'B'));
    final outings = await repo.watchOutings().first;
    expect(outings, hasLength(1));
    expect(outings.single.name, 'B');
  });

  test('deleteOuting removes it', () async {
    await repo.saveOuting(outing('o1'));
    await repo.deleteOuting('o1');
    expect(await repo.watchOutings().first, isEmpty);
  });
}