// ---------------------------------------------------------------------------
// Deciding what importing a pack would do, before it does anything
// (issue #34).
//
// Same shape as the backup planner (issue #24): plan first, apply second,
// nothing is written while planning. Two reasons it matters more here
// than for a backup:
//
//  - The person may already have imported this pack to this unit; "6 new
//    rules" would be a lie if five are duplicates.
//  - A pack from someone else can share a name with one of the person's
//    own rules. Dedup by pattern, not by name, so their edit is not
//    duplicated but a genuinely new message shape is.
//
// Dedup key is (pattern, unitId). Pattern is the functional identity:
// two templates with the same pattern match exactly the same messages,
// so a second one adds noise and nothing else.
// ---------------------------------------------------------------------------
import '../models/capture_source.dart';
import '../models/template.dart';
import '../models/template_pack.dart';
import '../repositories/repositories.dart';

class PackImportPlan {
  final TemplatePack pack;
  final String targetUnitId;

  /// Templates that will actually be added.
  final List<PackTemplate> toAdd;

  /// Templates whose pattern already exists on the target unit.
  final List<PackTemplate> duplicates;

  const PackImportPlan({
    required this.pack,
    required this.targetUnitId,
    required this.toAdd,
    required this.duplicates,
  });

  bool get changesNothing => toAdd.isEmpty;
  int get duplicateCount => duplicates.length;
}

class TemplatePackImporter {
  TemplatePackImporter._();

  static PackImportPlan plan({
    required TemplatePack pack,
    required String targetUnitId,
    required List<CaptureTemplate> existing,
  }) {
    final existingPatterns = {
      for (final t in existing)
        if (t.unitId == targetUnitId) t.pattern,
    };

    final toAdd = <PackTemplate>[];
    final duplicates = <PackTemplate>[];
    for (final t in pack.templates) {
      if (existingPatterns.contains(t.pattern)) {
        duplicates.add(t);
      } else {
        toAdd.add(t);
        // Guard against a pack with two identical patterns inside itself
        // (a hand-edited file could do this) — the second one would be
        // a duplicate of the first.
        existingPatterns.add(t.pattern);
      }
    }

    return PackImportPlan(
      pack: pack,
      targetUnitId: targetUnitId,
      toAdd: toAdd,
      duplicates: duplicates,
    );
  }

  /// Writes the plan's new templates to the target unit. Returns the
  /// number written.
  ///
  /// [sources] is the person's current capture-source list. If the pack
  /// suggests a package that is on the allow-list, the imported templates
  /// are bound to it; otherwise they are left unbound (match any allowed
  /// source), which is the correct default for SMS-based capture.
  static Future<int> apply({
    required PackImportPlan plan,
    required List<CaptureSource> sources,
    required TemplateRepository repo,
    DateTime Function()? now,
  }) async {
    if (plan.toAdd.isEmpty) return 0;

    String? suggestedSourceId;
    final hinted = plan.pack.suggestedPackage;
    if (hinted != null && hinted.isNotEmpty) {
      final candidateId = CaptureSource.idFor(hinted);
      if (sources.any((s) => s.id == candidateId && s.enabled)) {
        suggestedSourceId = candidateId;
      }
    }

    final clock = now ?? DateTime.now;
    var written = 0;
    for (final t in plan.toAdd) {
      final id = 'tpl_${clock().microsecondsSinceEpoch}_$written';
      await repo.saveTemplate(CaptureTemplate(
        id: id,
        unitId: plan.targetUnitId,
        captureSourceId: suggestedSourceId,
        name: t.name,
        direction: t.direction,
        pattern: t.pattern,
        fieldMap: t.fieldMap,
        sampleText: t.sampleText,
        enabled: t.enabled,
      ));
      written++;
    }
    return written;
  }
}