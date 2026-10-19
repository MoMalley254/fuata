import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/constants/preset_template_packs.dart';
import 'package:fuata/domain/logic/template_pack_codec.dart';

void main() {
  final mpesa = presetTemplatePacks.firstWhere((p) => p.id == 'mpesa_ke');

  group('round trip', () {
    test('decode(encode(pack)) re-encodes to exactly the same file', () {
      final first = TemplatePackCodec.encode(mpesa);
      final decoded = TemplatePackCodec.decode(first);
      expect(decoded.ok, isTrue);
      expect(TemplatePackCodec.encode(decoded.pack!), first);
    });

    test('every template survives with its pattern and field map', () {
      final decoded = TemplatePackCodec.decode(
        TemplatePackCodec.encode(mpesa),
      );
      final pack = decoded.pack!;
      expect(pack.templates, hasLength(mpesa.templates.length));
      for (var i = 0; i < pack.templates.length; i++) {
        final got = pack.templates[i];
        final want = mpesa.templates[i];
        expect(got.name, want.name);
        expect(got.direction, want.direction);
        expect(got.pattern, want.pattern);
        expect(got.fieldMap, want.fieldMap);
        expect(got.sampleText, want.sampleText);
      }
    });

    test('compact encode decodes back to the same pack', () {
      final compact = TemplatePackCodec.encodeCompact(mpesa);
      final decoded = TemplatePackCodec.decode(compact);
      expect(decoded.ok, isTrue);
      expect(decoded.pack!.templates.length, mpesa.templates.length);
    });
  });

  group('refuses files it cannot trust', () {
    test('not JSON', () {
      final r = TemplatePackCodec.decode('not a pack {');
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('JSON'));
    });

    test('a Fuata backup is refused with a helpful pointer', () {
      final r = TemplatePackCodec.decode(
        '{"format":"fuata-backup","formatVersion":1,"data":{}}',
      );
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('backup'));
      expect(r.errors.single, contains('Back up & restore'));
    });

    test('a newer format version asks the person to update', () {
      final root =
      jsonDecode(TemplatePackCodec.encode(mpesa)) as Map<String, dynamic>;
      root['formatVersion'] = 99;
      final r = TemplatePackCodec.decode(jsonEncode(root));
      expect(r.ok, isFalse);
      expect(r.errors.single, contains('newer version'));
    });

    test('missing required template fields', () {
      final root =
      jsonDecode(TemplatePackCodec.encode(mpesa)) as Map<String, dynamic>;
      final templates = root['templates'] as List;
      (templates.first as Map).remove('pattern');
      final r = TemplatePackCodec.decode(jsonEncode(root));
      expect(r.ok, isFalse);
      expect(r.errors.first, contains('pattern'));
    });

    test('an invalid regex in a pattern', () {
      final root =
      jsonDecode(TemplatePackCodec.encode(mpesa)) as Map<String, dynamic>;
      final templates = root['templates'] as List;
      (templates.first as Map)['pattern'] = '(unclosed';
      final r = TemplatePackCodec.decode(jsonEncode(root));
      expect(r.ok, isFalse);
      expect(r.errors.first, contains('pattern'));
    });

    test('an unknown field type', () {
      final root =
      jsonDecode(TemplatePackCodec.encode(mpesa)) as Map<String, dynamic>;
      final templates = root['templates'] as List;
      final fieldMap = (templates.first as Map)['fieldMap'] as Map;
      final firstKey = fieldMap.keys.first;
      fieldMap[firstKey] = 'bogus';
      final r = TemplatePackCodec.decode(jsonEncode(root));
      expect(r.ok, isFalse);
      expect(r.errors.first, contains('field type'));
    });

    test('an empty template list', () {
      final root = {
        'format': 'fuata-template-pack',
        'formatVersion': 1,
        'id': 'x',
        'name': 'x',
        'templates': <dynamic>[],
      };
      final r = TemplatePackCodec.decode(jsonEncode(root));
      expect(r.ok, isFalse);
      expect(r.errors.first, contains('at least one'));
    });
  });
}