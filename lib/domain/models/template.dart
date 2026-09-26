/// design.md TEMPLATE / ADR-007: the user pastes a sample message and
/// labels spans of it (amount, code, date, person, balance, fee); the app
/// turns that into a regex with one named group per labeled field. This
/// file is the template model plus the generator; matching a message
/// against a list of templates is `Parser` (logic/parser.dart).
library;

/// The kinds of field a user can label a span as (US-08). `ignore` isn't
/// listed in requirements.md's label set but is kept internal-only, not
/// exposed here, since v0.1's rule builder only offers the six above.
enum TemplateFieldType { amount, code, date, person, balance, fee }

/// `direction` on a Template: which way the transaction goes. `either`
/// lets the message decide at parse time (ui-design-brief.md 7.7 step 4)
/// — see `Parser._resolveType`.
enum TemplateDirection { spent, got, either }

/// One labeled span over `sampleText`, as produced by the rule builder UI
/// (#20). `end` is exclusive. The factory that consumes these assumes
/// they're already non-overlapping — the rule builder enforces that by
/// construction (tap-to-label chips can't cover the same character twice).
class LabeledSpan {
  final int start;
  final int end;
  final TemplateFieldType type;

  const LabeledSpan({
    required this.start,
    required this.end,
    required this.type,
  });
}

/// design.md TEMPLATE. `pattern` is a regex source string with one named
/// group per labeled field (`(?<amount>...)`, and `(?<amount2>...)` etc.
/// if a field type repeats, e.g. amount + fee are both money but distinct
/// groups); `fieldMap` maps each group name back to its [TemplateFieldType]
/// — this is tables.dart's `fieldMapJson` column, decoded.
class CaptureTemplate {
  final String id;
  final String unitId;
  final String? captureSourceId;
  final String name;
  final TemplateDirection direction;
  final String pattern;
  final Map<String, TemplateFieldType> fieldMap;
  final String sampleText;
  final int version;
  final bool enabled;

  const CaptureTemplate({
    required this.id,
    required this.unitId,
    required this.name,
    required this.direction,
    required this.pattern,
    required this.fieldMap,
    required this.sampleText,
    this.captureSourceId,
    this.version = 1,
    this.enabled = true,
  });

  /// Compiled on demand rather than cached, since a Template is an
  /// immutable value object handed around freely (Parser compiles it once
  /// per parse attempt); `dotAll` so a `date`/`person` group's `[\s\S]+?`
  /// isn't the only thing standing between us and a multi-line message
  /// silently failing to match.
  RegExp get compiled => RegExp(pattern, dotAll: true);

  /// ADR-007: builds a regex from a pasted sample plus the spans the user
  /// labeled over it. Literal text between, before and after the labels is
  /// regex-escaped, so punctuation in the sample (".", "(", "+", "$", ...)
  /// is matched literally rather than as regex syntax (testing.md P-04).
  /// Different names/numbers/amounts in a *future* message still match,
  /// because only the labeled spans became capture groups — everything
  /// else in the sample is now fixed literal text (testing.md P-03).
  factory CaptureTemplate.fromLabeledSample({
    required String id,
    required String unitId,
    String? captureSourceId,
    required String name,
    required TemplateDirection direction,
    required String sampleText,
    required List<LabeledSpan> labels,
    int version = 1,
    bool enabled = true,
  }) {
    final sorted = [...labels]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < sorted.length; i++) {
      assert(
        sorted[i].start >= sorted[i - 1].end,
        'Labeled spans must not overlap',
      );
    }

    final buffer = StringBuffer();
    final fieldMap = <String, TemplateFieldType>{};
    final usedCounts = <TemplateFieldType, int>{};
    var cursor = 0;

    for (final span in sorted) {
      buffer.write(_escapeLiteral(sampleText.substring(cursor, span.start)));
      final groupName = _nextGroupName(span.type, usedCounts);
      buffer.write('(?<$groupName>${_fieldPattern(span.type)})');
      fieldMap[groupName] = span.type;
      cursor = span.end;
    }
    buffer.write(_escapeLiteral(sampleText.substring(cursor)));
    return CaptureTemplate(
      id: id,
      unitId: unitId,
      captureSourceId: captureSourceId,
      name: name,
      direction: direction,
      pattern: buffer.toString(),
      fieldMap: fieldMap,
      sampleText: sampleText,
      version: version,
      enabled: enabled,
    );
  }

  CaptureTemplate copyWith({bool? enabled, String? name, int? version}) {
    return CaptureTemplate(
      id: id,
      unitId: unitId,
      captureSourceId: captureSourceId,
      name: name ?? this.name,
      direction: direction,
      pattern: pattern,
      fieldMap: fieldMap,
      sampleText: sampleText,
      version: version ?? this.version,
      enabled: enabled ?? this.enabled,
    );
  }

  /// testing.md P-11: round-trips through the same shape tables.dart's
  /// `fieldMapJson` column stores (group name -> field type name), so a
  /// repository just needs to `jsonEncode`/`jsonDecode` this map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'unitId': unitId,
    'captureSourceId': captureSourceId,
    'name': name,
    'direction': direction.name,
    'pattern': pattern,
    'fieldMap': fieldMap.map(
      (groupName, type) => MapEntry(groupName, type.name),
    ),
    'sampleText': sampleText,
    'version': version,
    'enabled': enabled,
  };

  factory CaptureTemplate.fromJson(Map<String, dynamic> json) {
    final rawFieldMap = json['fieldMap'] as Map<String, dynamic>;
    return CaptureTemplate(
      id: json['id'] as String,
      unitId: json['unitId'] as String,
      captureSourceId: json['captureSourceId'] as String?,
      name: json['name'] as String,
      direction: TemplateDirection.values.byName(json['direction'] as String),
      pattern: json['pattern'] as String,
      fieldMap: rawFieldMap.map(
        (groupName, typeName) => MapEntry(
          groupName,
          TemplateFieldType.values.byName(typeName as String),
        ),
      ),
      sampleText: json['sampleText'] as String,
      version: json['version'] as int? ?? 1,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  static String _nextGroupName(
    TemplateFieldType type,
    Map<TemplateFieldType, int> used,
  ) {
    final count = (used[type] ?? 0) + 1;
    used[type] = count;
    // Dart named-group names must start with a letter and be alphanumeric —
    // `type.name` (e.g. "amount") already is; appending the count for a
    // repeat keeps that true ("amount2").
    return count == 1 ? type.name : '${type.name}$count';
  }

  /// Escapes regex metacharacters so literal text from the sample is
  /// matched as itself. Dart's RegExp has no built-in escape helper.
  static String _escapeLiteral(String s) {
    return s.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (m) => '\\${m[0]}',
    );
  }

  /// The regex each field type matches against in a *future* message —
  /// deliberately more permissive than any one sample, since the amount,
  /// code, date etc. will differ every time (testing.md P-02/P-03).
  static String _fieldPattern(TemplateFieldType type) {
    switch (type) {
      case TemplateFieldType.amount:
      case TemplateFieldType.balance:
      case TemplateFieldType.fee:
        // Optional currency label/prefix, digits with optional thousands
        // separators, optional decimal part — "Ksh350.00", "KES 1,250",
        // "350" all match (testing.md P-02).
        return r'(?:[A-Za-z]{2,5}\.?\s*)?[\d,]+(?:\.\d+)?';
      case TemplateFieldType.code:
        return r'[A-Za-z0-9]+';
      case TemplateFieldType.date:
      case TemplateFieldType.person:
        // Non-greedy so it stops at the next literal chunk once compiled,
        // rather than swallowing the rest of the message.
        return r'[\s\S]+?';
    }
  }
}
