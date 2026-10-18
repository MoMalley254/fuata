import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/constants/preset_template_packs.dart';
import 'package:fuata/domain/logic/parser.dart';
import 'package:fuata/domain/models/template.dart';

void main() {
  test('every preset pack has at least one template', () {
    for (final pack in presetTemplatePacks) {
      expect(pack.templates, isNotEmpty, reason: pack.id);
    }
  });

  test('every preset template has an amount label', () {
    for (final pack in presetTemplatePacks) {
      for (final t in pack.templates) {
        expect(
          t.fieldMap.containsValue(TemplateFieldType.amount),
          isTrue,
          reason: '${pack.id} / ${t.name} has no amount field',
        );
      }
    }
  });

  group('each preset reads its own sample', () {
    for (final pack in presetTemplatePacks) {
      for (final t in pack.templates) {
        test('${pack.id} / ${t.name}', () {
          final template = CaptureTemplate(
            id: 'x',
            unitId: 'u',
            name: t.name,
            direction: t.direction,
            pattern: t.pattern,
            fieldMap: t.fieldMap,
            sampleText: t.sampleText,
          );
          final r = Parser.parse(
            t.sampleText,
            [template],
            currencyCode: 'KES',
          );
          expect(r.matched, isTrue, reason: t.sampleText);
          expect(r.fields!.amountMinor, isNotNull);
        });
      }
    }
  });
}