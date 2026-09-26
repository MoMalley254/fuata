import '../../domain/models/template.dart';

/// The labelable fields, palette order. Amount first deliberately: a
/// rule is useless without it, and both the palette UX and the save
/// button lean on that.
const palette = [
  (TemplateFieldType.amount, 'Amount', 'The money that moved'),
  (TemplateFieldType.code, 'Code', 'Reference like QW12ABC3'),
  (TemplateFieldType.date, 'When', 'Date and time'),
  (TemplateFieldType.person, 'Payee', 'Who or where, to or from'),
  (TemplateFieldType.balance, 'Balance', 'New balance quoted'),
  (TemplateFieldType.fee, 'Fee', 'Any charge taken'),
];

String fieldName(TemplateFieldType type) => switch (type) {
  TemplateFieldType.amount => 'Amount',
  TemplateFieldType.code => 'Code',
  TemplateFieldType.date => 'When',
  TemplateFieldType.person => 'Payee',
  TemplateFieldType.balance => 'Balance',
  TemplateFieldType.fee => 'Fee',
};

/// One whitespace-delimited run of the sample, with its offsets so a
/// label span can be built from token indices.
class WordToken {
  const WordToken(this.start, this.end, this.text);
  final int start;
  final int end; // exclusive
  final String text;
}

/// A human-readable version of what a rule will demand from a future
/// message: the sample with each labeled span replaced by
/// `xxxx(FieldName)`. Anything after the *last* labeled span is dropped,
/// because [CaptureTemplate.fromLabeledSample] ends the compiled pattern
/// at the last label — real messages vary in their tail (URLs, per-message
/// counters, "see all your balances"), and requiring an exact tail would
/// break the rule on the very next message.
///
/// Purely presentational; the compiled regex is unaffected.
String describePattern({
  required String sampleText,
  required List<LabeledSpan> labels,
}) {
  if (labels.isEmpty) return sampleText;
  final sorted = [...labels]..sort((a, b) => a.start.compareTo(b.start));
  final buffer = StringBuffer();
  var cursor = 0;
  for (final span in sorted) {
    if (span.start < cursor) continue; // defensive: overlapping span
    buffer.write(sampleText.substring(cursor, span.start));
    buffer.write('xxxx(${fieldName(span.type)})');
    cursor = span.end;
  }
  return buffer.toString();
}