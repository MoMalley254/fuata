// Issue #24: the backup file format. Pure Dart, no database.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/backup_codec.dart';
import 'package:fuata/domain/models/backup_snapshot.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';

import 'backup_test_data.dart';

void main() {
  String encodeFull({bool includeRawText = false}) => BackupCodec.encode(
    fullSnapshot(),
    exportedAt: exportedAt,
    includeRawText: includeRawText,
  );

  /// Encode a valid file, let [mutate] break it, decode the result.
  BackupDecodeResult decodeMutated(void Function(Map<String, dynamic> root) mutate) {
    final root = jsonDecode(encodeFull()) as Map<String, dynamic>;
    mutate(root);
    return BackupCodec.decode(jsonEncode(root));
  }

  Map<String, dynamic> data(Map<String, dynamic> root) =>
      root['data'] as Map<String, dynamic>;

  group('round trip', () {
    test('decode(encode(x)) re-encodes to exactly the same file', () {
      final first = encodeFull();
      final decoded = BackupCodec.decode(first);

      expect(decoded.errors, isEmpty);
      expect(decoded.ok, isTrue);
      expect(decoded.warnings, isEmpty);
      final again = BackupCodec.encode(decoded.snapshot!, exportedAt: exportedAt);
      expect(again, first);
    });

    test('every table survives with its values', () {
      final s = BackupCodec.decode(encodeFull()).snapshot!;

      expect(s.units.map((u) => u.name), ['Cash', 'M-Pesa']);
      expect(s.units.first.color.toARGB32(), 0xFF2E9E6B);
      expect(s.transactions, hasLength(2));
      expect(s.transactions.last.amountMinor, 120000);
      expect(s.templates.single.fieldMap.keys, ['amount']);
      expect(s.limits.map((l) => l.period), [LimitPeriod.day, LimitPeriod.week]);
      expect(s.limits.last.warnAt, 0.6);
      expect(s.categories.single.name, 'Food');
      expect(s.settings!.name, 'Wanjiru');
      expect(s.settings!.themeMode, AppThemeMode.dark);
      expect(s.settings!.homeSections, {HomeSection.units});
      expect(s.settings!.bannerUnitIds, {'u1'});
      expect(s.settings!.bannerUnitsMode, BannerUnitsMode.all);
    });

    test('exportedAt is read back', () {
      expect(BackupCodec.decode(encodeFull()).exportedAt, exportedAt);
    });

    test('a category round-trips with its sort order and archive flag (#83)',
            () {
          final snapshot = BackupSnapshot(categories: [
            const BackupCategory(
              id: 'c1',
              name: 'Food',
              emoji: '🍲',
              colorValue: 0xFFE07A5F,
              sortOrder: 3,
              archived: true,
            ),
          ]);
          final decoded = BackupCodec.decode(
            BackupCodec.encode(snapshot, exportedAt: exportedAt),
          );
          expect(decoded.errors, isEmpty);
          final c = decoded.snapshot!.categories.single;
          expect(c.sortOrder, 3);
          expect(c.archived, isTrue);
        });

    test('a pre-#83 backup reads with sort order 0 and not archived', () {
      final root = jsonDecode(
        BackupCodec.encode(
          BackupSnapshot(categories: const [
            BackupCategory(
              id: 'c1', name: 'Food', emoji: '🍲', colorValue: 0xFFE07A5F,
            ),
          ]),
          exportedAt: exportedAt,
        ),
      ) as Map<String, dynamic>;
      final cat = ((root['data'] as Map)['categories'] as List).first as Map;
      cat.remove('sortOrder');
      cat.remove('archived');

      final decoded = BackupCodec.decode(jsonEncode(root));
      expect(decoded.errors, isEmpty);
      final c = decoded.snapshot!.categories.single;
      expect(c.sortOrder, 0);
      expect(c.archived, isFalse);
    });
  });

  group('original message text (ADR-009)', () {
    test('left out by default', () {
      final json = encodeFull();
      expect(json, isNot(contains('secret message')));
      final decoded = BackupCodec.decode(json);
      expect(decoded.snapshot!.transactions.first.rawText, isNull);
      expect(decoded.includesRawText, isFalse);
    });

    test('included only when asked for', () {
      final decoded = BackupCodec.decode(encodeFull(includeRawText: true));
      expect(decoded.snapshot!.transactions.first.rawText, 'secret message');
      expect(decoded.includesRawText, isTrue);
    });
  });

  group('refuses files it cannot trust', () {
    test('not JSON', () {
      final r = BackupCodec.decode('this is not json {');
      expect(r.ok, isFalse);
      expect(r.snapshot, isNull);
      expect(r.errors.single, contains('JSON'));
    });

    test('JSON that is not a Fuata backup', () {
      expect(BackupCodec.decode('[1,2,3]').ok, isFalse);
      expect(BackupCodec.decode('{"format":"something-else"}').ok, isFalse);
    });

    test('a newer format version asks the person to update', () {
      final r = decodeMutated((root) => root['formatVersion'] = 99);
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('newer version'));
    });

    test('a missing or invalid version', () {
      expect(decodeMutated((root) => root.remove('formatVersion')).ok, isFalse);
      expect(decodeMutated((root) => root['formatVersion'] = 0).ok, isFalse);
      expect(decodeMutated((root) => root['formatVersion'] = '1').ok, isFalse);
    });

    test('no data section', () {
      expect(decodeMutated((root) => root.remove('data')).ok, isFalse);
    });

    test('a missing required field names where', () {
      final r = decodeMutated(
            (root) => (data(root)['units'] as List).first.remove('createdAt'),
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('units[0].createdAt'));
    });

    test('an unknown enum value names where', () {
      final r = decodeMutated(
            (root) => (data(root)['transactions'] as List).first['type'] = 'bogus',
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('transactions[0].type'));
    });

    test('a money amount that is not a whole number', () {
      final r = decodeMutated(
            (root) => (data(root)['transactions'] as List).first['amountMinor'] = 12.5,
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('amountMinor'));
    });

    test('an unreadable date', () {
      final r = decodeMutated(
            (root) => (data(root)['transactions'] as List).first['occurredAt'] = 'yesterday',
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('occurredAt'));
    });

    test('the same id twice in one table', () {
      final r = decodeMutated((root) {
        final txs = data(root)['transactions'] as List;
        txs.add(Map<String, dynamic>.from(txs.first as Map));
      });
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('more than once'));
    });

    test('a table that is not a list', () {
      final r = decodeMutated((root) => data(root)['units'] = {'a': 1});
      expect(r.ok, isFalse);
    });

    test('a message pattern that is not a valid regex', () {
      final r = decodeMutated(
            (root) => (data(root)['templates'] as List).first['pattern'] = '(unclosed',
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('pattern'));
    });

    test('limit alert levels out of order', () {
      final r = decodeMutated((root) {
        final limit = (data(root)['limits'] as List).first as Map;
        limit['warnAt'] = 0.95;
        limit['dangerAt'] = 0.9;
      });
      expect(r.ok, isFalse);
    });

    test('a per-unit limit with no unit', () {
      final r = decodeMutated(
            (root) => (data(root)['limits'] as List).last['unitId'] = null,
      );
      expect(r.ok, isFalse);
    });

    test('one bad record rejects the whole file', () {
      final r = decodeMutated((root) {
        (data(root)['transactions'] as List).last['type'] = 'bogus';
      });
      expect(r.snapshot, isNull);
    });

    test('lists at most 40 problems and counts the rest', () {
      final r = decodeMutated((root) {
        final proto = Map<String, dynamic>.from(
          (data(root)['transactions'] as List).first as Map,
        )..remove('unitId');
        data(root)['transactions'] = [
          for (var i = 0; i < 100; i++) {...proto, 'id': 'bad$i'},
        ];
      });
      expect(r.ok, isFalse);
      expect(r.errors, hasLength(40));
      expect(r.moreErrors, 60);
    });
  });

  group('tidies without rejecting', () {
    test('a limit id that does not match its scope and period is normalised', () {
      final r = decodeMutated(
            (root) => (data(root)['limits'] as List).first['id'] = 'my-own-id',
      );
      expect(r.ok, isTrue);
      expect(r.snapshot!.limits.first.id, 'l_overall_day');
      expect(r.warnings, isNotEmpty);
    });

    test('an overall limit that names a unit ignores the unit', () {
      final r = decodeMutated(
            (root) => (data(root)['limits'] as List).first['unitId'] = 'u1',
      );
      expect(r.ok, isTrue);
      expect(r.snapshot!.limits.first.unitId, isNull);
      expect(r.warnings, isNotEmpty);
    });

    test('an app id is derived from its package name', () {
      final r = decodeMutated(
            (root) => (data(root)['captureSources'] as List).first['id'] = 'whatever',
      );
      expect(r.ok, isTrue);
      expect(r.snapshot!.captureSources.single.id, 'src_com.example.messages');
    });

    test('unknown extra keys are ignored', () {
      final r = decodeMutated((root) {
        root['somethingNew'] = true;
        (data(root)['units'] as List).first['futureField'] = 42;
      });
      expect(r.ok, isTrue);
    });

    test('a missing table is an empty table', () {
      final r = decodeMutated((root) => data(root).remove('limits'));
      expect(r.ok, isTrue);
      expect(r.snapshot!.limits, isEmpty);
    });
  });

  group('settings are forgiving', () {
    test('an unknown value keeps the default and warns', () {
      final r = decodeMutated(
            (root) => (data(root)['settings'] as Map)['themeMode'] = 'neon',
      );
      expect(r.ok, isTrue);
      expect(r.snapshot!.settings!.themeMode, AppSettings.defaults.themeMode);
      expect(r.warnings.single, contains('themeMode'));
    });

    test('a wrong-typed toggle keeps the default and warns', () {
      final r = decodeMutated(
            (root) => (data(root)['settings'] as Map)['bannerEnabled'] = 'yes',
      );
      expect(r.ok, isTrue);
      expect(r.snapshot!.settings!.bannerEnabled, AppSettings.defaults.bannerEnabled);
    });

    test('no settings section means null settings', () {
      final r = decodeMutated((root) => data(root).remove('settings'));
      expect(r.ok, isTrue);
      expect(r.snapshot!.settings, isNull);
    });
  });
  test('an archived unit keeps both its flag and its date (#80)', () {
    final archivedAt = DateTime.utc(2026, 10, 15, 12);
    final snapshot = BackupSnapshot(units: [
      unit('u1').copyWith(archived: true, archivedAt: archivedAt),
    ]);

    final encoded = BackupCodec.encode(snapshot, exportedAt: exportedAt);
    final decoded = BackupCodec.decode(encoded);

    expect(decoded.errors, isEmpty);
    final u = decoded.snapshot!.units.single;
    expect(u.archived, isTrue);
    expect(u.archivedAt, archivedAt);
  });

  test('a backup made before #80 still reads as archived, without a date', () {
    // Encode a unit with the archived flag but no archivedAt key at all,
    // the shape an older Fuata would have produced.
    final root = jsonDecode(
      BackupCodec.encode(
        BackupSnapshot(units: [unit('u1').copyWith(archived: true)]),
        exportedAt: exportedAt,
      ),
    ) as Map<String, dynamic>;
    final unitJson = (root['data']['units'] as List).first as Map;
    unitJson.remove('archivedAt');

    final decoded = BackupCodec.decode(jsonEncode(root));
    expect(decoded.errors, isEmpty);
    expect(decoded.snapshot!.units.single.archived, isTrue);
    expect(decoded.snapshot!.units.single.archivedAt, isNull);
  });

  test('the banner units mode round-trips (#86)', () {
    for (final m in BannerUnitsMode.values) {
      final snapshot = BackupSnapshot(
        settings: customSettings().copyWith(bannerUnitsMode: m),
      );
      final decoded = BackupCodec.decode(
        BackupCodec.encode(snapshot, exportedAt: exportedAt),
      );
      expect(decoded.errors, isEmpty);
      expect(decoded.snapshot!.settings!.bannerUnitsMode, m);
    }
  });

  test('an older file with ids but no mode reads as "selected" (#86)', () {
    // Same shape a backup made before #86 would have produced.
    final root = jsonDecode(
      BackupCodec.encode(
        BackupSnapshot(settings: customSettings()),
        exportedAt: exportedAt,
      ),
    ) as Map<String, dynamic>;
    ((root['data'] as Map)['settings'] as Map).remove('bannerUnitsMode');
    // customSettings() has bannerUnitIds: {'u1'} — non-empty, so the
    // inference must land on `selected`, not on the default.
    final decoded = BackupCodec.decode(jsonEncode(root));
    expect(decoded.errors, isEmpty);
    expect(decoded.snapshot!.settings!.bannerUnitsMode,
        BannerUnitsMode.selected);
  });

  test('an older file with no ids and no mode reads as "all" (#86)', () {
    final snapshot = BackupSnapshot(
      settings: customSettings().copyWith(bannerUnitIds: <String>{}),
    );
    final root = jsonDecode(
      BackupCodec.encode(snapshot, exportedAt: exportedAt),
    ) as Map<String, dynamic>;
    ((root['data'] as Map)['settings'] as Map).remove('bannerUnitsMode');

    final decoded = BackupCodec.decode(jsonEncode(root));
    expect(decoded.errors, isEmpty);
    expect(decoded.snapshot!.settings!.bannerUnitsMode, BannerUnitsMode.all);
  });

  test('app lock is deliberately not carried by a backup (#28)', () {
    // A lock is a property of the *device*, not of the money. Restoring
    // a file onto a new phone must not lock the person out of an app
    // they just installed and have not set a lock on.
    final snapshot = BackupSnapshot(
      settings: customSettings().copyWith(
        appLockEnabled: true,
        appLockBiometric: true,
      ),
    );
    final json = BackupCodec.encode(snapshot, exportedAt: exportedAt);

    expect(json, isNot(contains('appLock')));

    final decoded = BackupCodec.decode(json);
    expect(decoded.errors, isEmpty);
    expect(decoded.snapshot!.settings!.appLockEnabled, isFalse);
    expect(decoded.snapshot!.settings!.appLockBiometric, isFalse);
  });

  test('the widget options round-trip (#113)', () {
    final snapshot = BackupSnapshot(
      settings: customSettings().copyWith(
        widgetUnitsMode: BannerUnitsMode.selected,
        widgetUnitIds: {'u1'},
        widgetHeadline: BannerHeadline.totalIHave,
        widgetShowProgress: false,
        widgetShowSplit: false,
        widgetVariant: WidgetVariant.compact,
      ),
    );
    final decoded = BackupCodec.decode(
      BackupCodec.encode(snapshot, exportedAt: exportedAt),
    );
    expect(decoded.errors, isEmpty);
    final s = decoded.snapshot!.settings!;
    expect(s.widgetUnitsMode, BannerUnitsMode.selected);
    expect(s.widgetUnitIds, {'u1'});
    expect(s.widgetHeadline, BannerHeadline.totalIHave);
    expect(s.widgetShowProgress, isFalse);
    expect(s.widgetShowSplit, isFalse);
    expect(s.widgetVariant, WidgetVariant.compact);
  });

  test('the summary notification options round-trip', () {
    final snapshot = BackupSnapshot(
      settings: customSettings().copyWith(
        summaryNotificationsEnabled: true,
        summaryDailyEnabled: true,
        summaryDailyMinute: 480, // 8:00 AM
        summaryWeeklyEnabled: true,
        summaryWeeklyWeekday: 1, // Monday
        summaryWeeklyMinute: 540, // 9:00 AM
        summaryMonthlyEnabled: false,
        summaryMonthlyDay: 15,
        summaryMonthlyMinute: 600, // 10:00 AM
      ),
    );
    final decoded = BackupCodec.decode(
      BackupCodec.encode(snapshot, exportedAt: exportedAt),
    );
    expect(decoded.errors, isEmpty);
    final s = decoded.snapshot!.settings!;
    expect(s.summaryNotificationsEnabled, isTrue);
    expect(s.summaryDailyEnabled, isTrue);
    expect(s.summaryDailyMinute, 480);
    expect(s.summaryWeeklyEnabled, isTrue);
    expect(s.summaryWeeklyWeekday, 1);
    expect(s.summaryWeeklyMinute, 540);
    expect(s.summaryMonthlyEnabled, isFalse);
    expect(s.summaryMonthlyDay, 15);
    expect(s.summaryMonthlyMinute, 600);
  });

  test('a backup made before #113 leaves the widget at its defaults', () {
    final root = jsonDecode(
      BackupCodec.encode(
        BackupSnapshot(settings: customSettings()),
        exportedAt: exportedAt,
      ),
    ) as Map<String, dynamic>;
    final settings = (root['data'] as Map)['settings'] as Map;
    for (final k in [
      'widgetUnitsMode', 'widgetUnitIds', 'widgetHeadline',
      'widgetShowProgress', 'widgetShowSplit', 'widgetVariant',
    ]) {
      settings.remove(k);
    }

    final decoded = BackupCodec.decode(jsonEncode(root));
    expect(decoded.errors, isEmpty);
    final d = AppSettings.defaults;
    final s = decoded.snapshot!.settings!;
    expect(s.widgetUnitsMode, d.widgetUnitsMode);
    expect(s.widgetHeadline, d.widgetHeadline);
    expect(s.widgetShowProgress, d.widgetShowProgress);
    expect(s.widgetShowSplit, d.widgetShowSplit);
    expect(s.widgetVariant, d.widgetVariant);
  });

  test('a backup made before summary settings leaves them at defaults', () {
    final root = jsonDecode(
      BackupCodec.encode(
        BackupSnapshot(settings: customSettings()),
        exportedAt: exportedAt,
      ),
    ) as Map<String, dynamic>;
    final settings = (root['data'] as Map)['settings'] as Map;
    for (final k in [
      'summaryNotificationsEnabled', 'summaryDailyEnabled', 'summaryDailyMinute',
      'summaryWeeklyEnabled', 'summaryWeeklyWeekday', 'summaryWeeklyMinute',
      'summaryMonthlyEnabled', 'summaryMonthlyDay', 'summaryMonthlyMinute',
    ]) {
      settings.remove(k);
    }

    final decoded = BackupCodec.decode(jsonEncode(root));
    expect(decoded.errors, isEmpty);
    final d = AppSettings.defaults;
    final s = decoded.snapshot!.settings!;
    expect(s.summaryNotificationsEnabled, d.summaryNotificationsEnabled);
    expect(s.summaryDailyEnabled, d.summaryDailyEnabled);
    expect(s.summaryDailyMinute, d.summaryDailyMinute);
    expect(s.summaryWeeklyEnabled, d.summaryWeeklyEnabled);
    expect(s.summaryWeeklyWeekday, d.summaryWeeklyWeekday);
    expect(s.summaryWeeklyMinute, d.summaryWeeklyMinute);
    expect(s.summaryMonthlyEnabled, d.summaryMonthlyEnabled);
    expect(s.summaryMonthlyDay, d.summaryMonthlyDay);
    expect(s.summaryMonthlyMinute, d.summaryMonthlyMinute);
  });
}