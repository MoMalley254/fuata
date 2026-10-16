import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:fuata/widgets/provider_error_card.dart';

import '../../data/constants/rule_builder_constants.dart';
import '../../domain/logic/parser.dart';
import '../../domain/models/template.dart';
import '../../domain/models/unit.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/rule_builder/field_palette.dart';
import '../../widgets/rule_builder/found_card.dart';
import '../../widgets/rule_builder/hint_card.dart';
import '../../widgets/rule_builder/pattern_preview_card.dart';
import '../../widgets/rule_builder/step_label.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Rule builder (issue #20, ui-design-brief.md 7.7): paste a sample
/// message, tap (or long-press then tap) word chips to label spans as
/// Amount / Code / When / Payee / Balance / Fee, watch a live preview of
/// what the rule extracts, test it against a second message, then save
/// it as a named rule for a unit.
///
/// The rule itself is pure domain work: labels become [LabeledSpan]s and
/// [CaptureTemplate.fromLabeledSample] turns them into the regex (ADR-007),
/// and [Parser] runs both the preview and the test — this screen owns no
/// parsing logic of its own, it only feeds the domain pieces.
///
/// [sampleText] (issue #21) seeds the sample box — the review inbox's
/// "Teach me" opens this screen with the unreadable message pre-pasted.
///
/// Deferred, flagged rather than silently dropped: "This part changes"
/// wildcards (ui-design-brief.md 7.7's palette has it; the template model
/// only turns *labeled* spans into capture groups today, so a varying
/// word outside a label becomes fixed literal text and will break the
/// rule — worth a model addition in a follow-up).

class RuleBuilderScreen extends ConsumerStatefulWidget {
  final String? unitId;
  final CaptureTemplate? existing;

  /// A message to pre-fill in step 1 (e.g. an unparsed capture from the
  /// review inbox's "Teach me").
  final String? sampleText;
  const RuleBuilderScreen({
    super.key,
    this.unitId,
    this.existing,
    this.sampleText,
  });

  @override
  ConsumerState<RuleBuilderScreen> createState() => _RuleBuilderScreenState();
}

class _RuleBuilderScreenState extends ConsumerState<RuleBuilderScreen> {
  final _sampleController = TextEditingController();
  final _testController = TextEditingController();
  final _nameController = TextEditingController();

  /// Sorted by start; non-overlapping by construction — labeling a range
  /// first removes any spans that overlap it (the rule builder enforces
  /// what CaptureTemplate.fromLabeledSample only asserts).
  List<LabeledSpan> _labels = [];

  /// Long-press on a word starts phrase mode; the next word tapped
  /// becomes the other end of the range.
  int? _rangeAnchor;
  int? _rangeFocus;

  TemplateDirection _direction = TemplateDirection.either;
  String? _unitId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _unitId = existing.unitId;
      _direction = existing.direction;
      _nameController.text = existing.name;
      // Setting .text before the listener is attached means the
      // clear-labels-on-change listener below won't fire on seed.
      _sampleController.text = existing.sampleText;
      _labels = _labelsFromTemplate(existing);
    } else {
      _unitId = widget.unitId;
      // #21: arriving from the review inbox's "Teach me" — seed the
      // sample before the listener attaches so the labels aren't wiped.
      final sample = widget.sampleText;
      if (sample != null && sample.trim().isNotEmpty) {
        _sampleController.text = sample.trim();
      }
    }
    // Rebuild the chips on every keystroke, and — important — drop all
    // labels when the sample itself changes, since their offsets point
    // into the old text.
    _sampleController.addListener(() {
      setState(() {
        _labels = [];
        _rangeAnchor = null;
        _rangeFocus = null;
      });
    });
    _testController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sampleController.dispose();
    _testController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _sampleText => _sampleController.text;

  /// Rebuilds the labeled spans from a saved template. The template doesn't
  /// store label offsets, but the compiled [pattern] was generated *from*
  /// them, so re-matching the pattern against the original sample and
  /// reading each named group's [RegExpMatch.start]/[RegExpMatch.end]
  /// recovers exactly the same spans. Returns empty if the pattern no
  /// longer matches its own sample (hand-edited or corrupted template) —
  /// the person can just re-label in that case.
  List<LabeledSpan> _labelsFromTemplate(CaptureTemplate t) {
    try {
      final match = t.compiled.firstMatch(t.sampleText);
      if (match == null) return const [];

      // Dart's RegExpMatch exposes whole-match bounds as the `start`/`end`
      // properties, and per-group strings via `namedGroup(name)`, but has
      // no start(group)/end(group) accessor. So recover each group's
      // offset by locating its string inside the match range, advancing a
      // cursor past each hit so a later group can never re-match text
      // already claimed by an earlier one. `groupNames` yields names in
      // pattern order, which is label order, which is sample order — the
      // same order the cursor walks in.
      final spans = <LabeledSpan>[];
      var cursor = match.start;
      for (final name in match.groupNames) {
        final type = t.fieldMap[name];
        if (type == null) continue;
        final value = match.namedGroup(name);
        if (value == null || value.isEmpty) continue;
        final at = t.sampleText.indexOf(value, cursor);
        if (at < 0) continue;
        final end = at + value.length;
        spans.add(LabeledSpan(start: at, end: end, type: type));
        cursor = end;
      }
      spans.sort((a, b) => a.start.compareTo(b.start));
      return spans;
    } catch (_) {
      return const [];
    }
  }

  List<WordToken> get _tokens {
    final out = <WordToken>[];
    for (final m in RegExp(r'\S+').allMatches(_sampleText)) {
      var text = m[0]!;
      var end = m.end;
      // Sentence-ending punctuation belongs to the sentence, not to the
      // field. Peeling it off here means a labelled span for "Ksh0.00."
      // covers only "Ksh0.00", and the period becomes plain literal text
      // in the generated regex — which is exactly what we want, because
      // money/date/code patterns never include a trailing period.
      final trailing = RegExp(r'[.,;:!?]+$').firstMatch(text);
      if (trailing != null) {
        final cut = trailing.end - trailing.start;
        text = text.substring(0, text.length - cut);
        end -= cut;
      }
      if (text.isEmpty) continue;
      out.add(WordToken(m.start, end, text));
    }
    return out;
  }

  bool get _canSave =>
      !_saving &&
      _sampleText.trim().isNotEmpty &&
      _labels.any((l) => l.type == TemplateFieldType.amount) &&
      _unitId != null &&
      _nameController.text.trim().isNotEmpty &&
      _readsOwnSample;

  /// #72 (F11a): a rule whose pattern can't match the sample it was built
  /// from can never fire, so saving it would silently do nothing. True when
  /// there is nothing to check yet.
  bool get _readsOwnSample {
    final template = _previewTemplate;
    return template == null || template.readsOwnSample;
  }

  (int, int)? get _selection {
    final a = _rangeAnchor;
    if (a == null) return null;
    final b = _rangeFocus ?? a;
    return a <= b ? (a, b) : (b, a);
  }

  TemplateFieldType? _typeAt(int tokenIndex) {
    final t = _tokens[tokenIndex];
    for (final s in _labels) {
      if (s.start <= t.start && t.end <= s.end) return s.type;
    }
    return null;
  }

  void _labelRange(int first, int last, TemplateFieldType type) {
    final tokens = _tokens;
    final start = tokens[first].start;
    final end = tokens[last].end;
    setState(() {
      _labels.removeWhere((s) => s.start < end && s.end > start);
      _labels.add(LabeledSpan(start: start, end: end, type: type));
      _labels.sort((a, b) => a.start.compareTo(b.start));
      _rangeAnchor = null;
      _rangeFocus = null;
    });
  }

  void _removeAt(int tokenIndex) {
    final t = _tokens[tokenIndex];
    setState(
      () => _labels.removeWhere((s) => s.start <= t.start && t.end <= s.end),
    );
  }

  void _onWordTap(int i) {
    final anchor = _rangeAnchor;
    if (anchor != null) {
      setState(() => _rangeFocus = i);
      return;
    }
    final existing = _typeAt(i);
    if (existing != null) {
      _removeAt(i);
    } else {
      _openPalette(i, i);
    }
  }

  Future<void> _openPalette(int first, int last) async {
    final tokens = _tokens;
    final text = _sampleText.substring(tokens[first].start, tokens[last].end);
    final type = await showModalBottomSheet<TemplateFieldType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FieldPalette(selectionText: text),
    );
    if (type != null) _labelRange(first, last, type);
  }

  Future<void> _pasteSample() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    _sampleController.text = text.trim();
  }

  /// The rule as it stands right now, id/name disposable — used for the
  /// live preview and the "try another message" test.
  CaptureTemplate? get _previewTemplate {
    if (_sampleText.trim().isEmpty || _labels.isEmpty) return null;
    final unitId = _unitId;
    try {
      return CaptureTemplate.fromLabeledSample(
        id: 'preview',
        unitId: unitId ?? 'preview',
        name: 'preview',
        direction: _direction,
        sampleText: _sampleText,
        labels: List.of(_labels),
      );
    } catch (_) {
      return null; // overlapping labels — unreachable by construction, but don't crash on it
    }
  }

  Future<void> _save(MoneyUnit unit) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final existing = widget.existing;
    final template = CaptureTemplate.fromLabeledSample(
      id: existing?.id ?? 'tpl_${now.microsecondsSinceEpoch}',
      unitId: unit.id,
      captureSourceId: existing?.captureSourceId,
      name: _nameController.text.trim(),
      direction: _direction,
      sampleText: _sampleText,
      labels: List.of(_labels),
    );
    try {
      // insertOnConflictUpdate in the repository means the same id
      // overwrites — that's what makes this an update rather than a
      // duplicate save.
      await ref.read(templateRepositoryProvider).saveTemplate(template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Saved "${template.name}" for ${unit.name}.'
                : 'Updated "${template.name}".',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save, please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Teach a message' : 'Edit rule'),
      ),
      body: SafeArea(
        child: unitsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load your money right now",
            error: e,
            onRetry: () => ref.invalidate(unitsProvider),
          ),
          data: (units) {
            if (units.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Add some money first — rules belong to a unit.',
                    style: AppTypography.bodyMd.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            _unitId ??= units.first.id;
            final unit = units.firstWhere((u) => u.id == _unitId);
            final currencyCode = unit.currencyCode;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                AppSpacing.xl,
              ),
              children: [
                StepLabel('1 · Paste a sample message'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _sampleController,
                  maxLines: 6,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Paste one real message from your bank or mobile money',
                  ),
                  style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pasteSample,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Paste from clipboard'),
                  ),
                ),
                if (_sampleText.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  StepLabel('2 · Tap words to say what they are'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tap a word to label it. Long-press, then tap another word, to label a whole phrase. Tap a coloured word to remove its label.',
                    style: AppTypography.bodySm.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildWordChips(c),
                  if (_rangeAnchor != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildRangeBar(c),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  StepLabel("3 · Here's what I found"),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPreviewCard(c, currencyCode),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPatternPreview(c),
                  const SizedBox(height: AppSpacing.lg),
                  StepLabel('4 · Try another message'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTester(c, currencyCode),
                  const SizedBox(height: AppSpacing.lg),
                  StepLabel('5 · Save this rule'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildRuleDetails(c, units),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: AppTypography.bodySm.copyWith(
                        color: c.statusDanger,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canSave ? () => _save(unit) : null,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.existing == null
                                  ? 'Save rule'
                                  : 'Save changes',
                            ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWordChips(AppColors c) {
    final tokens = _tokens;
    final selection = _selection;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (var i = 0; i < tokens.length; i++)
            WordLabelChip(
              key: ValueKey('tok_$i'),
              word: tokens[i].text,
              assignedField: _typeAt(i) == null ? null : fieldName(_typeAt(i)!),
              highlighted:
                  selection != null && i >= selection.$1 && i <= selection.$2,
              onTap: () => _onWordTap(i),
              onLongPress: () => setState(() {
                _rangeAnchor = i;
                _rangeFocus = i;
              }),
            ),
        ],
      ),
    );
  }

  /// Shown while a phrase is selected: the field palette, applied to the
  /// whole range on tap.
  Widget _buildRangeBar(AppColors c) {
    final selection = _selection!;
    final tokens = _tokens;
    final text = _sampleText.substring(
      tokens[selection.$1].start,
      tokens[selection.$2].end,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.primary.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Labeling “$text”',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (type, name, _) in palette)
                AppChoiceChip(
                  label: name,
                  selected: false,
                  onTap: () => _labelRange(selection.$1, selection.$2, type),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _rangeAnchor = null;
                _rangeFocus = null;
              }),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(AppColors c, String currencyCode) {
    final template = _previewTemplate;
    if (_labels.isEmpty || template == null) {
      return HintCard(
        c: c,
        message:
            'Tap a word above and pick what it is — start with the amount.',
      );
    }
    if (!template.readsOwnSample) {
      return HintCard(
        c: c,
        message: "This rule can't read its own sample, so a label probably includes something it can't match. Try labeling a smaller part of the message.",
      );
    }
    try {
      final result = Parser.parse(_sampleText, [
        template,
      ], currencyCode: currencyCode);
      final fields = result.fields;
      if (!result.matched || fields == null || fields.amountMinor == null) {
        return HintCard(
          c: c,
          message: 'Every rule needs an Amount — tap the amount in the message and label it.',
        );
      }
      return FoundCard(fields: fields, currencyCode: currencyCode);
    } catch (e) {
      return HintCard(
        c: c,
        message: 'Could not build the preview. Try labeling a smaller part '
            'of the message.',
      );
    }
  }

  Widget _buildPatternPreview(AppColors c) {
    if (_labels.isEmpty) return const SizedBox.shrink();
    return PatternPreviewCard(
      description: describePattern(sampleText: _sampleText, labels: _labels),
    );
  }

  Widget _buildTester(AppColors c, String currencyCode) {
    final template = _previewTemplate;
    final input = _testController.text;
    Widget? resultCard;
    if (input.trim().isNotEmpty) {
      if (template == null) {
        resultCard = HintCard(c: c, message: 'Label the sample above first.');
      } else {
        try {
          final result = Parser.parse(input, [
            template,
          ], currencyCode: currencyCode);
          final fields = result.fields;
          if (!result.matched || fields == null || fields.amountMinor == null) {
            resultCard = HintCard(
              c: c,
              message: "Couldn't read this one yet. That's normal while you're still labeling — or this message is shaped differently.",
            );
          } else {
            resultCard = FoundCard(fields: fields, currencyCode: currencyCode);
          }
        } catch (_) {
          return HintCard(
            c: c,
            message: 'Could not build the preview. Try labeling a smaller part '
                'of the message.',
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _testController,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'Paste a different message of the same kind',
          ),
          style: AppTypography.bodyMd.copyWith(color: c.onSurface),
        ),
        if (resultCard != null) ...[
          const SizedBox(height: AppSpacing.sm),
          resultCard,
        ],
      ],
    );
  }

  Widget _buildRuleDetails(AppColors c, List<MoneyUnit> units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Name it, e.g. "M-Pesa · money out"',
          ),
          style: AppTypography.bodyLg.copyWith(color: c.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'For',
          style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: units.map((u) {
            return AppChoiceChip(
              label: '${u.iconEmoji} ${u.name}',
              selected: u.id == _unitId,
              onTap: () => setState(() => _unitId = u.id),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'This message means',
          style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppChoiceChip(
              label: 'Spent',
              selected: _direction == TemplateDirection.spent,
              onTap: () => setState(() => _direction = TemplateDirection.spent),
            ),
            AppChoiceChip(
              label: 'Got',
              selected: _direction == TemplateDirection.got,
              onTap: () => setState(() => _direction = TemplateDirection.got),
            ),
            AppChoiceChip(
              label: 'Let the message decide',
              selected: _direction == TemplateDirection.either,
              onTap: () =>
                  setState(() => _direction = TemplateDirection.either),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(switch (_direction) {
          TemplateDirection.spent => 'Every match counts as money out.',
          TemplateDirection.got => 'Every match counts as money in.',
          TemplateDirection.either =>
            'Decided per message: looks for "received", "credited" or '
                '"deposit" to call it money in, otherwise money out.',
        }, style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}
