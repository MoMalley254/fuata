/// design.md TEMPLATE / ADR-007: the user pastes a sample message and
/// labels spans of it (amount, code, date, person, balance, fee); the app
/// turns that into a regex with one named group per labeled field. This
/// file is the template model plus the generator; matching a message
/// against a list of templates is `Parser` (logic/parser.dart).
library;

/// The kinds of field a user can label a span as (US-08). `ignore` isn't
/// listed in requirements.md's label set but is kept internal-only, not
/// exposed here, since v0.1's rule builder only offers the six above.
enum TemplateFieldType { amount, code, date, person, balance, fee, custom }

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

  /// #56 Human-readable name for a [TemplateFieldType.custom] label.
  /// Required when [type] is custom; null for built-in fields.
  final String? customName;

  const LabeledSpan({
    required this.start,
    required this.end,
    required this.type,
    this.customName,
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

  ///#56
  final Map<String, String> customFieldNames; // group name -> display name

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
    this.customFieldNames = const {},
  });

  /// Compiled on demand rather than cached, since a Template is an
  /// immutable value object handed around freely (Parser compiles it once
  /// per parse attempt); `dotAll` so literal `.` in older saved patterns
  /// still spans line breaks.
  RegExp get compiled => RegExp(pattern, dotAll: true);

  /// #72: true when this rule's pattern matches the very sample it was
  /// built from. A label that covers text its field pattern can't match
  /// (the old `Ref:AC123` code bug) makes this false, and the rule
  /// builder uses it to stop the person saving a rule that can never fire.
  bool get readsOwnSample => compiled.hasMatch(sampleText);

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

    final customFieldNames = <String, String>{};
    var customCount = 0;

    for (var i = 0; i < sorted.length; i++) {
      final span = sorted[i];
      buffer.write(_escapeLiteral(sampleText.substring(cursor, span.start)));

      final isCustom = span.type == TemplateFieldType.custom;

      final groupName = isCustom
          ? 'custom${++customCount}' //#56
          : _nextGroupName(span.type, usedCounts);

      if (isCustom) {
        final label = span.customName?.trim();
        if (label == null || label.isEmpty) {
          throw ArgumentError('A custom field label needs a name.');
        }
        customFieldNames[groupName] = label;
      }

      final isFreeText = span.type == TemplateFieldType.person || isCustom;
      final fieldPattern = isFreeText && i == sorted.length - 1
          ? _lastFreeTextPattern(sampleText.substring(span.end))
          : _fieldPattern(span.type);

      // #72 (F11b): a lazy person match with nothing after it stops at one
      // character, so the *last* label needs an explicit boundary.
      // final fieldPattern =
      //     span.type == TemplateFieldType.person && i == sorted.length - 1
      //     ? _lastPersonPattern(sampleText.substring(span.end))
      //     : _fieldPattern(span.type);
      buffer.write('(?<$groupName>$fieldPattern)');
      fieldMap[groupName] = span.type;
      cursor = span.end;
    }

    // #20 Intentionally no trailing literal: the pattern ends where the last
    // labeled field ends. Real messages have variable tails (URLs, "see all
    // your balances", counters, per-message limits) that we don't want to
    // require on every future message. Leading literals before the first
    // label are still kept — a header like "Confirmed." pins the rule to
    // the right kind of message.
    //     buffer.write(_escapeLiteral(sampleText.substring(cursor)));
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
      customFieldNames: customFieldNames,
    );
  }

  CaptureTemplate copyWith({
    bool? enabled,
    String? name,
    int? version,
    Map<String, String>? customFieldNames,
  }) {
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
      customFieldNames: customFieldNames ?? this.customFieldNames,
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
    if (customFieldNames.isNotEmpty) 'customFieldNames': customFieldNames,
  };

  factory CaptureTemplate.fromJson(Map<String, dynamic> json) {
    final rawFieldMap = json['fieldMap'] as Map<String, dynamic>;

    final rawCustom = json['customFieldNames'];
    final customFieldNames = <String, String>{};
    if (rawCustom is Map) {
      rawCustom.forEach((key, value) {
        if (key is String && value is String && value.trim().isNotEmpty) {
          customFieldNames[key] = value.trim();
        }
      });
    }

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
      customFieldNames: customFieldNames,
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
        return r'(?:[A-Za-z]{2,5}\.?\s*)?[\d,]+(?:\.\d+)?[.,;:!?]?';
      case TemplateFieldType.code:
        // #72 (F11a): letters and digits, with punctuation allowed
        // *between* them (Ref:AC123, TXN-45/B, ab_12.3) but never leading
        // or trailing, so a sentence-ending "." or ":" stays outside.
        return r'[A-Za-z0-9]+(?:[:_\-./][A-Za-z0-9]+)*';
      case TemplateFieldType.date:
        // #72 (F11c): a real date shape rather than a lazy match, so it
        // doesn't depend on what follows. Numeric dates (28/9/26,
        // 28-09-2026, 28.09.2026, 2026-09-28) or "28 Sep 2026" /
        // "28-Sep-26", then an optional time (12 or 24 hour, optional
        // "at", optional seconds, optional AM/PM). Parser._parseDate reads
        // the same shapes.
        return r'(?:(?:on|at)\s+)?'
            r'(?:\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}'
            r'|\d{1,2}[ -][A-Za-z]{3,9}[ -]\d{2,4})'
            r'(?:(?:[ ,]*|T)(?:at\s+)?\d{1,2}:\d{2}(?::\d{2})?'
            r'(?:\s*[AaPp][Mm])?)?';
      case TemplateFieldType.person:
        // Non-greedy so it stops at the next literal chunk once compiled,
        // rather than swallowing the rest of the message. Never crosses a
        // line break.
        return r'[^\n]+?';

      case TemplateFieldType.custom:
        // Same shape as a person: free text bounded by the surrounding
        // literals, or by the end of the line when it is the last label.
        return r'[^\n]+?';
    }
  }

  /// #72 (F11b): the pattern for a person label that is the *last* label.
  /// [rest] is the sample text after the label. With text after it, stop at
  /// the next few literal characters (a zero-width lookahead, so the
  /// variable tail of the message stays unconstrained). With nothing after
  /// it, take the rest of the line.
  static String _lastFreeTextPattern(String rest) {
    final lineEnd = rest.indexOf('\n');
    final line = lineEnd < 0 ? rest : rest.substring(0, lineEnd);
    if (line.isEmpty) return r'[^\n]+';
    final boundary = line.length <= 4 ? line : line.substring(0, 4);
    return '[^\\n]+?(?=${_escapeLiteral(boundary)})';
  }
}
