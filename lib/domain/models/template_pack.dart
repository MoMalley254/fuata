// ---------------------------------------------------------------------------
// A template pack (issue #34): a named, shareable set of message-reading
// rules.
//
// Deliberately *not* a CaptureTemplate. A pack's templates have no unit
// binding, no id and no capture source — those are assigned at import,
// because the receiver's units are not the sender's. A pack's template is
// the compiled pattern + field map, the same shape CaptureTemplate.toJson
// writes, so sharing is "the rule as data".
//
// No Flutter imports. The rule builder's test suite can construct a pack
// from labeled samples using CaptureTemplate.fromLabeledSample — the
// presets do exactly that.
// ---------------------------------------------------------------------------
import 'template.dart';

class PackTemplate {
  final String name;
  final TemplateDirection direction;
  final String pattern;
  final Map<String, TemplateFieldType> fieldMap;
  final String sampleText;
  final bool enabled;

  const PackTemplate({
    required this.name,
    required this.direction,
    required this.pattern,
    required this.fieldMap,
    required this.sampleText,
    this.enabled = true,
  });
}

class TemplatePack {
  /// Stable id: `mpesa_ke`, `airtel_ke`, `kenyan_banks`, or `exported_<ts>`
  /// for a pack made by Fuata on a person's phone. Nothing depends on the
  /// id being unique across devices; it's for humans reading the JSON.
  final String id;

  final String name;

  /// One or two sentences, shown on the pack tile and the preview sheet.
  /// Null for an exported pack (the exporter rarely has anything to say).
  final String? description;

  /// A hint about which Android package this pack's messages arrive from,
  /// e.g. `com.android.mms`. At import, if that package is on the
  /// person's allow-list, the templates are bound to it; otherwise they
  /// match any allowed source (the common case — most SMS is captured
  /// through the messages app). Never a requirement.
  final String? suggestedPackage;

  final List<PackTemplate> templates;

  /// True when the pack came from `preset_template_packs.dart`. False
  /// when it came from a file or a QR. Presentation only — the import
  /// path treats both the same.
  final bool isPreset;

  const TemplatePack({
    required this.id,
    required this.name,
    required this.templates,
    this.description,
    this.suggestedPackage,
    this.isPreset = false,
  });
}