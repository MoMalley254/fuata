import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/constants/keep_alive_guides.dart';

void main() {
  // Issue #36: the guide is picked by Build.MANUFACTURER (lower-cased by
  // the native side, but be forgiving anyway).
  test('Xiaomi gets the Xiaomi guide, in any case', () {
    expect(keepAliveGuideFor('xiaomi'), same(xiaomiKeepAliveGuide));
    expect(keepAliveGuideFor('Xiaomi'), same(xiaomiKeepAliveGuide));
    expect(keepAliveGuideFor('  XIAOMI '), same(xiaomiKeepAliveGuide));
  });

  test('Redmi and Poco sub-brands share the Xiaomi guide', () {
    expect(keepAliveGuideFor('redmi'), same(xiaomiKeepAliveGuide));
    expect(keepAliveGuideFor('poco'), same(xiaomiKeepAliveGuide));
  });

  test('anything else, or nothing, gets the generic fallback', () {
    expect(keepAliveGuideFor('samsung'), same(genericKeepAliveGuide));
    expect(keepAliveGuideFor(''), same(genericKeepAliveGuide));
    expect(keepAliveGuideFor(null), same(genericKeepAliveGuide));
    expect(genericKeepAliveGuide.isFallback, isTrue);
  });

  test('every guide has steps, and every manufacturer key is lower-case', () {
    for (final e in keepAliveGuides.entries) {
      expect(e.key, e.key.toLowerCase());
      expect(e.value.steps, isNotEmpty);
    }
    expect(genericKeepAliveGuide.steps, isNotEmpty);
  });

  test('a step button only ever points at a known public settings screen', () {
    final all = [...keepAliveGuides.values, genericKeepAliveGuide];
    for (final g in all) {
      for (final s in g.steps) {
        if (s.target != null) {
          expect(SettingsTarget.values, contains(s.target));
          expect(s.targetLabel, isNotNull, reason: 'a button needs a label');
        }
      }
    }
  });
}
