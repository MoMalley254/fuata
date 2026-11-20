import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/paste_parser.dart';

void main() {
  test('no units -> noUnits, whatever the text', () {
    final r = PasteParser.parse('anything', units: const [], templatesByUnit: const {});
    expect(r.parsed, isNull);
    expect(r.failure, PasteFailure.noUnits);
  });

  test('every failure has a message to show', () {
    for (final f in PasteFailure.values) {
      expect(f.message, isNotEmpty);
    }
  });
}
