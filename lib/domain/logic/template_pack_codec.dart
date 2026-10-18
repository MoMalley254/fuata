// ---------------------------------------------------------------------------
// The template-pack file / QR format (issue #34).
//
//   {
//     "format": "fuata-template-pack",
//     "formatVersion": 1,
//     "id": "mpesa_ke",
//     "name": "M-PESA Kenya",
//     "description": "...",
//     "suggestedPackage": "com.android.mms",
//     "templates": [
//       {
//         "name": "M-PESA · money out",
//         "direction": "spent",
//         "pattern": "UIS9P8GJV5 Confirmed...",
//         "fieldMap": {"code": "code", "amount": "amount"},
//         "sampleText": "UIS9P8GJV5 Confirmed. Ksh500.00 sent to ...",
//         "enabled": true
//       }
//     ]
//   }
//
// Pure Dart. `encode` never fails; `decode` never throws — every problem
// comes back as a readable message, and any error rejects the file whole.
// A pack with a bad template would import as a broken rule; refusing the
// whole file is the only honest answer.
//
// No Flutter imports. No `unitId`, no template ids, no `captureSourceId` —
// a pack is unit-agnostic by design. Those are assigned at import.
// ---------------------------------------------------------------------------
import 'dart:convert';

import '../models/template.dart';
import '../models/template_pack.dart';

/// What [TemplatePackCodec.decode] found. Same shape as BackupDecodeResult
/// (issue #24) because the same reasoning applies: a partially-understood
/// pack is a partially-broken rule, which is worse than no pack at all.
class PackDecodeResult {
  final TemplatePack? pack;
  final List<String> errors;
  final int moreErrors;

  const PackDecodeResult({
    required this.pack,
    required this.errors,
    this.moreErrors = 0,
  });

  factory PackDecodeResult.failed(String message) =>
      PackDecodeResult(pack: null, errors: [message]);

  bool get ok => pack != null && errors.isEmpty;
}

class TemplatePackCodec {
  TemplatePackCodec._();

  static const formatName = 'fuata-template-pack';
  static const currentVersion = 1;
  static const _maxListedErrors = 20;

  // ---------------------------------------------------------------- encode

  static String encode(TemplatePack pack) {
    return const JsonEncoder.withIndent('  ').convert(_toMap(pack));
  }

  /// The compact form used by QR. Same semantic content as [encode], but
  /// no whitespace and no pretty-printing — a QR has a hard 2953-byte
  /// ceiling at the lowest error correction, and every saved byte counts.
  static String encodeCompact(TemplatePack pack) => jsonEncode(_toMap(pack));

  static Map<String, dynamic> _toMap(TemplatePack pack) => {
    'format': formatName,
    'formatVersion': currentVersion,
    'id': pack.id,
    'name': pack.name,
    if (pack.description != null) 'description': pack.description,
    if (pack.suggestedPackage != null)
      'suggestedPackage': pack.suggestedPackage,
    'templates': [
      for (final t in pack.templates)
        {
          'name': t.name,
          'direction': t.direction.name,
          'pattern': t.pattern,
          'fieldMap': {
            for (final e in t.fieldMap.entries) e.key: e.value.name,
          },
          'sampleText': t.sampleText,
          'enabled': t.enabled,
        },
    ],
  };

  // ---------------------------------------------------------------- decode

  static PackDecodeResult decode(String text) {
    Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return PackDecodeResult.failed(
        "This isn't readable JSON. It may be cut off, or it isn't a Fuata "
            'pack.',
      );
    }
    if (root is! Map<String, dynamic>) {
      return PackDecodeResult.failed("This isn't a Fuata pack.");
    }

    final format = root['format'];
    if (format == 'fuata-backup') {
      // Helpful, precise refusal — the two files look similar at a glance
      // and a person could easily pick the wrong one.
      return PackDecodeResult.failed(
        'This is a Fuata backup, not a template pack. Backups go to '
            'Settings → Privacy & data → Back up & restore.',
      );
    }
    if (format != formatName) {
      return PackDecodeResult.failed("This isn't a Fuata template pack.");
    }

    final version = root['formatVersion'];
    if (version is! int || version < 1) {
      return PackDecodeResult.failed(
        "This pack has no valid version number, so it can't be trusted.",
      );
    }
    if (version > currentVersion) {
      return PackDecodeResult.failed(
        'This pack was made by a newer version of Fuata (format $version). '
            'Update Fuata, then try again.',
      );
    }

    final errors = <String>[];
    var more = 0;
    void error(String message) {
      if (errors.length < _maxListedErrors) {
        errors.add(message);
      } else {
        more++;
      }
    }

    String str(Map<String, dynamic> m, String key, String path,
        {bool required = true}) {
      final v = m[key];
      if (v is String) return v;
      if (!required && v == null) return '';
      error('$path.$key: expected text.');
      return '';
    }

    String? strOrNull(Map<String, dynamic> m, String key, String path) {
      final v = m[key];
      if (v == null) return null;
      if (v is String) return v;
      error('$path.$key: expected text or null.');
      return null;
    }

    final rawId = str(root, 'id', 'pack');
    final rawName = str(root, 'name', 'pack');
    if (rawId.trim().isEmpty) error('pack.id: must not be empty.');
    if (rawName.trim().isEmpty) error('pack.name: must not be empty.');

    final rawTemplates = root['templates'];
    final parsed = <PackTemplate>[];
    if (rawTemplates is! List) {
      error('pack.templates: expected a list.');
    } else if (rawTemplates.isEmpty) {
      error('pack.templates: a pack needs at least one template.');
    } else {
      for (var i = 0; i < rawTemplates.length; i++) {
        final entry = rawTemplates[i];
        if (entry is! Map<String, dynamic>) {
          error('templates[$i]: expected an object.');
          continue;
        }
        final path = 'templates[$i]';
        final name = str(entry, 'name', path);
        if (name.trim().isEmpty) error('$path.name: must not be empty.');

        final dirRaw = entry['direction'];
        final direction = TemplateDirection.values
            .where((d) => d.name == dirRaw)
            .firstOrNull;
        if (direction == null) {
          error('$path.direction: unknown value "$dirRaw".');
          continue;
        }

        final pattern = str(entry, 'pattern', path);
        if (pattern.isEmpty) {
          error('$path.pattern: must not be empty.');
        } else {
          try {
            RegExp(pattern, dotAll: true);
          } on FormatException {
            error('$path.pattern: not a valid message pattern.');
          }
        }

        final fieldMap = <String, TemplateFieldType>{};
        final rawMap = entry['fieldMap'];
        if (rawMap is! Map<String, dynamic>) {
          error('$path.fieldMap: expected an object.');
        } else if (rawMap.isEmpty) {
          error('$path.fieldMap: at least one field is required.');
        } else {
          rawMap.forEach((group, type) {
            final match = TemplateFieldType.values
                .where((t) => t.name == type)
                .firstOrNull;
            if (match == null) {
              error('$path.fieldMap.$group: unknown field type.');
            } else {
              fieldMap[group] = match;
              if (!pattern.contains('(?<$group>')) {
                error('$path: field "$group" is not in its pattern.');
              }
            }
          });
        }

        final sample = str(entry, 'sampleText', path);
        final enabled = entry['enabled'];
        if (enabled is! bool) {
          // Enabled is defaulted rather than required: a pack written by
          // hand or by an older tool that omits it should still import.
          error('$path.enabled: expected true or false.');
        }

        parsed.add(PackTemplate(
          name: name,
          direction: direction,
          pattern: pattern,
          fieldMap: fieldMap,
          sampleText: sample,
          enabled: enabled is bool ? enabled : true,
        ));
      }
    }

    if (errors.isNotEmpty) {
      return PackDecodeResult(pack: null, errors: errors, moreErrors: more);
    }

    return PackDecodeResult(
      pack: TemplatePack(
        id: rawId,
        name: rawName,
        description: strOrNull(root, 'description', 'pack'),
        suggestedPackage: strOrNull(root, 'suggestedPackage', 'pack'),
        templates: parsed,
        isPreset: false,
      ),
      errors: const [],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}