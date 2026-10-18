import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/constants/preset_template_packs.dart';
import 'package:fuata/domain/logic/template_pack_import.dart';
import 'package:fuata/domain/models/capture_source.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/template_pack.dart';
import 'package:fuata/domain/repositories/repositories.dart';

void main() {
  final mpesa = presetTemplatePacks.firstWhere((p) => p.id == 'mpesa_ke');

  CaptureTemplate existingFromPack(PackTemplate t, String unitId) =>
      CaptureTemplate(
        id: 'existing_${t.name.hashCode}',
        unitId: unitId,
        name: t.name,
        direction: t.direction,
        pattern: t.pattern,
        fieldMap: t.fieldMap,
        sampleText: t.sampleText,
        enabled: true,
      );

  group('plan', () {
    test('on a fresh unit, everything is new', () {
      final plan = TemplatePackImporter.plan(
        pack: mpesa,
        targetUnitId: 'u1',
        existing: const [],
      );
      expect(plan.toAdd, hasLength(mpesa.templates.length));
      expect(plan.duplicates, isEmpty);
      expect(plan.changesNothing, isFalse);
    });

    test('a pack already on the unit is all duplicates', () {
      final existing = [
        for (final t in mpesa.templates) existingFromPack(t, 'u1'),
      ];
      final plan = TemplatePackImporter.plan(
        pack: mpesa,
        targetUnitId: 'u1',
        existing: existing,
      );
      expect(plan.toAdd, isEmpty);
      expect(plan.duplicates, hasLength(mpesa.templates.length));
      expect(plan.changesNothing, isTrue);
    });

    test('a pattern only counts on the same unit', () {
      final existing = [
        for (final t in mpesa.templates) existingFromPack(t, 'u_other'),
      ];
      final plan = TemplatePackImporter.plan(
        pack: mpesa,
        targetUnitId: 'u1',
        existing: existing,
      );
      expect(plan.toAdd, hasLength(mpesa.templates.length));
      expect(plan.duplicates, isEmpty);
    });

    test('a hand-edited pack with two identical patterns imports one', () {
      final t = mpesa.templates.first;
      final pack = TemplatePack(
        id: 'p', name: 'p',
        templates: [t, t],  // same instance twice
      );
      final plan = TemplatePackImporter.plan(
        pack: pack,
        targetUnitId: 'u1',
        existing: const [],
      );
      expect(plan.toAdd, hasLength(1));
      expect(plan.duplicates, hasLength(1));
    });
  });

  group('apply', () {
    test('binds to the pack\'s suggested package when enabled', () async {
      final repo = _FakeTemplateRepo();
      final plan = TemplatePackImporter.plan(
        pack: mpesa,
        targetUnitId: 'u1',
        existing: const [],
      );
      final written = await TemplatePackImporter.apply(
        plan: plan,
        sources: [
          CaptureSource(
            id: CaptureSource.idFor('com.safaricom.mpesa'),
            packageName: 'com.safaricom.mpesa',
            displayName: 'M-PESA',
            enabled: true,
          ),
        ],
        repo: repo,
        now: () => DateTime(2026, 10, 17),
      );
      expect(written, plan.toAdd.length);
      expect(repo.saved, hasLength(plan.toAdd.length));
      for (final t in repo.saved) {
        expect(t.captureSourceId, CaptureSource.idFor('com.safaricom.mpesa'));
      }
    });

    test('leaves captureSourceId null when the suggested package is not on '
        'the allow-list', () async {
      final repo = _FakeTemplateRepo();
      final plan = TemplatePackImporter.plan(
        pack: mpesa, targetUnitId: 'u1', existing: const [],
      );
      await TemplatePackImporter.apply(
        plan: plan,
        sources: const [],  // nothing enabled
        repo: repo,
      );
      expect(repo.saved.every((t) => t.captureSourceId == null), isTrue);
    });

    test('an empty plan writes nothing', () async {
      final repo = _FakeTemplateRepo();
      final plan = PackImportPlan(
        pack: mpesa, targetUnitId: 'u1',
        toAdd: const [], duplicates: mpesa.templates,
      );
      expect(
        await TemplatePackImporter.apply(
          plan: plan, sources: const [], repo: repo,
        ),
        0,
      );
      expect(repo.saved, isEmpty);
    });
  });
}

class _FakeTemplateRepo implements TemplateRepository {
  final saved = <CaptureTemplate>[];

  @override
  Stream<List<CaptureTemplate>> watchTemplates({String? unitId}) =>
      Stream.value(saved);

  @override
  Future<void> saveTemplate(CaptureTemplate template) async =>
      saved.add(template);

  @override
  Future<void> deleteTemplate(String templateId) async {}
}