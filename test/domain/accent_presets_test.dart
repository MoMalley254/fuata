// Issue #118: the picker offers eight presets and a custom swatch. The
// swatch needs to know which of those it is, exactly — an approximate
// match would leave two swatches looking selected at once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/models/settings.dart';

void main() {
  test('every preset is recognised', () {
    for (final s in AppAccents.swatches) {
      expect(AppAccents.isPreset(s), isTrue, reason: '$s');
    }
  });

  test('an arbitrary colour is not a preset', () {
    expect(AppAccents.isPreset(const Color(0xFF123456)), isFalse);
    expect(AppAccents.isPreset(const Color(0xFFFF00FF)), isFalse);
    expect(AppAccents.isPreset(const Color(0xFF000000)), isFalse);
  });

  test('the default accent is one of the presets', () {
    // Otherwise a fresh install would open with the custom swatch
    // showing itself as selected, which is wrong — the person never
    // picked anything.
    expect(AppAccents.isPreset(AppAccents.teal), isTrue);
  });
}