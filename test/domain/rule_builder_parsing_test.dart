import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/parser.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/transaction.dart';

import '../fixtures/messages.dart';

/// Issue #72 (issue-26 F11): rule builder code, payee and date parsing.
/// The big loop is the F11e corpus: for every message shape, label it the
/// way a person would, build the rule, check the rule reads its own
/// sample, then read a second message of the same shape with different
/// values. The second step is the one that proves the rule generalises.
void main() {
  CaptureTemplate build(
    String sample,
    List<(TemplateFieldType, String)> labels, {
    TemplateDirection direction = TemplateDirection.spent,
  }) {
    return CaptureTemplate.fromLabeledSample(
      id: 't',
      unitId: 'u',
      name: 'test rule',
      direction: direction,
      sampleText: sample,
      labels: [
        for (final (type, text) in labels)
          LabeledSpan(
            start: sample.indexOf(text),
            end: sample.indexOf(text) + text.length,
            type: type,
          ),
      ],
    );
  }

  void expectFields(ParseResult result, Expected want) {
    expect(result.matched, isTrue, reason: 'rule should match the message');
    final f = result.fields!;
    expect(result.type, want.type);
    expect(f.amountMinor, want.amountMinor);
    if (want.person != null) expect(f.counterparty, want.person);
    if (want.code != null) expect(f.code, want.code);
    if (want.date != null) expect(f.occurredAt, want.date);
    if (want.feeMinor != null) expect(f.feeMinor, want.feeMinor);
    if (want.balanceMinor != null) {
      expect(f.balanceAfterMinor, want.balanceMinor);
    }
    expect(f.unreadable, isEmpty);
  }

  group('F11e message corpus', () {
    for (final fx in messageFixtures) {
      group(fx.name, () {
        late CaptureTemplate template;
        setUp(() {
          template = build(fx.sample, fx.labels, direction: fx.direction);
        });

        test('the rule reads its own sample', () {
          expect(template.readsOwnSample, isTrue);
        });

        test('the sample parses to what was labelled', () {
          expectFields(
            Parser.parse(fx.sample, [template], currencyCode: 'KES'),
            fx.expectedForSample,
          );
        });

        test('a second message of the same shape parses with new values', () {
          expectFields(
            Parser.parse(fx.second, [template], currencyCode: 'KES'),
            fx.expectedForSecond,
          );
        });
      });
    }

    test('failed and reversed messages do not become transactions', () {
      final sent = messageFixtures.firstWhere((f) => f.id == 'mpesa_sent');
      final template = build(sent.sample, sent.labels);
      for (final message in notASentTransaction) {
        expect(
          Parser.parse(message, [template], currencyCode: 'KES').matched,
          isFalse,
          reason: message,
        );
      }
    });
  });

  group('F11a code labels', () {
    final coop = messageFixtures.firstWhere((f) => f.id == 'coop');

    test('"Ref:AC4368F03026" is taken whole as the code', () {
      final template = build(coop.sample, coop.labels);
      final r = Parser.parse(coop.sample, [template], currencyCode: 'KES');
      expect(r.fields!.code, 'Ref:AC4368F03026');
    });

    test('a code at the end of a sentence leaves the full stop outside', () {
      const sample = 'Your code is AB12CD3. Thanks for banking with us.';
      final template = build(sample, [(TemplateFieldType.code, 'AB12CD3')]);
      final m = template.compiled.firstMatch(
        'Your code is XY99ZZ1. Thanks for banking with us.',
      );
      expect(m!.namedGroup('code'), 'XY99ZZ1');
    });

    test('a rule whose label cannot match is reported by readsOwnSample', () {
      // Hand-made pattern that cannot match the sample it claims to be
      // from, like the old code pattern did for "Ref:AC123".
      const broken = CaptureTemplate(
        id: 'b',
        unitId: 'u',
        name: 'broken',
        direction: TemplateDirection.spent,
        pattern: r'Ref:(?<code>[A-Za-z0-9]+)X',
        fieldMap: {'code': TemplateFieldType.code},
        sampleText: 'Ref:AC123 paid',
      );
      expect(broken.readsOwnSample, isFalse);
    });
  });

  group('F11b payee as the last label', () {
    final coop = messageFixtures.firstWhere((f) => f.id == 'coop');
    final labels = [
      for (final l in coop.labels)
        if (l.$1 != TemplateFieldType.date) l,
    ];

    test('the payee is read in full, not just its first letter', () {
      final template = build(coop.sample, labels);
      final r = Parser.parse(coop.sample, [template], currencyCode: 'KES');
      expect(r.fields!.counterparty, 'MORRIS KINYUA NJUGUNA-0743230001');
    });

    test('and in a later message with a different payee', () {
      final template = build(coop.sample, labels);
      final r = Parser.parse(coop.second, [template], currencyCode: 'KES');
      expect(r.fields!.counterparty, 'JANE WANJIKU MWANGI-0711000222');
    });

    test('a payee that ends the message runs to the end of the line', () {
      const sample = 'Paid KES 100 to ACME TRADERS LIMITED';
      final template = build(sample, [
        (TemplateFieldType.amount, 'KES 100'),
        (TemplateFieldType.person, 'ACME TRADERS LIMITED'),
      ]);
      final r = Parser.parse(
        'Paid KES 250 to OTHER SHOP KE',
        [template],
        currencyCode: 'KES',
      );
      expect(r.fields!.counterparty, 'OTHER SHOP KE');
    });

    test('a payee never runs across a line break', () {
      const sample = 'Paid KES 100 to ACME TRADERS LIMITED';
      final template = build(sample, [
        (TemplateFieldType.amount, 'KES 100'),
        (TemplateFieldType.person, 'ACME TRADERS LIMITED'),
      ]);
      final r = Parser.parse(
        'Paid KES 250 to OTHER SHOP\nSee your balance',
        [template],
        currencyCode: 'KES',
      );
      expect(r.fields!.counterparty, 'OTHER SHOP');
    });
  });

  group('F11c dates', () {
    DateTime? read(String dateText) {
      const sample = 'Paid Ksh10.00 on 21/9/26 at 1:12 PM ref AB1';
      final template = build(sample, [
        (TemplateFieldType.amount, 'Ksh10.00'),
        (TemplateFieldType.date, '21/9/26 at 1:12 PM'),
      ]);
      final r = Parser.parse(
        'Paid Ksh10.00 on $dateText ref AB1',
        [template],
        currencyCode: 'KES',
      );
      expect(r.matched, isTrue, reason: dateText);
      return r.fields!.occurredAt;
    }

    test('dash-separated date with 12-hour time', () {
      expect(read('28-09-2026 11:03 PM'), DateTime(2026, 9, 28, 23, 3));
    });

    test('slash date with "at" and a two-digit year still parses', () {
      expect(read('28/9/26 at 11:03 PM'), DateTime(2026, 9, 28, 23, 3));
    });

    test('dotted date with 24-hour time', () {
      expect(read('28.09.2026 23:03'), DateTime(2026, 9, 28, 23, 3));
    });

    test('ISO with a space still parses', () {
      expect(read('2026-09-28 23:03'), DateTime(2026, 9, 28, 23, 3));
    });

    test('day, month name and two-digit year', () {
      expect(read('28-Sep-26'), DateTime(2026, 9, 28));
    });

    test('day, month name, year and time', () {
      expect(read('28 Sep 2026 14:05'), DateTime(2026, 9, 28, 14, 5));
    });

    test('a date that cannot be read is reported, not hidden', () {
      const sample = 'Paid Ksh10.00 on 28 Sep 2026 ref AB1';
      final template = build(sample, [
        (TemplateFieldType.amount, 'Ksh10.00'),
        (TemplateFieldType.date, '28 Sep 2026'),
      ]);
      final r = Parser.parse(
        'Paid Ksh10.00 on 28 Foo 2026 ref AB1',
        [template],
        currencyCode: 'KES',
      );
      expect(r.matched, isTrue);
      expect(r.fields!.occurredAt, isNull);
      expect(r.fields!.unreadable[TemplateFieldType.date], '28 Foo 2026');
    });

    test('a date that was never labelled is not reported as unreadable', () {
      const sample = 'Paid Ksh10.00 to SHOP';
      final template = build(sample, [(TemplateFieldType.amount, 'Ksh10.00')]);
      final r = Parser.parse(sample, [template], currencyCode: 'KES');
      expect(r.fields!.occurredAt, isNull);
      expect(r.fields!.unreadable, isEmpty);
    });
  });

  test('a received message with direction "either" is a got', () {
    final fx = messageFixtures.firstWhere((f) => f.id == 'mpesa_received');
    final template = build(fx.sample, fx.labels, direction: fx.direction);
    expect(
      Parser.parse(fx.sample, [template], currencyCode: 'KES').type,
      TxType.got,
    );
  });

  group('wildcard spans (#55)', () {
    const sample =
        'Ref:AC4368F03026: Dear MORRIS, MPESA transfer of KES 500 to '
        'JOHN DOE at 28-09-2026 11:03 PM was successful.';
    const second =
        'Ref:ZZ9911223344: Dear MORRIS, MPESA transfer of KES 1,250 to '
        'JANE DOE at 05-10-2026 09:15 AM was successful.';

    CaptureTemplate build() => CaptureTemplate.fromLabeledSample(
      id: 't-wildcard',
      unitId: 'u',
      name: 'wildcard test',
      direction: TemplateDirection.spent,
      sampleText: sample,
      labels: [
        LabeledSpan(
          start: sample.indexOf('AC4368F03026'),
          end: sample.indexOf('AC4368F03026') + 'AC4368F03026'.length,
          type: TemplateFieldType.wildcard,
        ),
        LabeledSpan(
          start: sample.indexOf('KES 500'),
          end: sample.indexOf('KES 500') + 'KES 500'.length,
          type: TemplateFieldType.amount,
        ),
        LabeledSpan(
          start: sample.indexOf('JOHN DOE'),
          end: sample.indexOf('JOHN DOE') + 'JOHN DOE'.length,
          type: TemplateFieldType.person,
        ),
        LabeledSpan(
          start: sample.indexOf('28-09-2026 11:03 PM'),
          end: sample.indexOf('28-09-2026 11:03 PM') +
              '28-09-2026 11:03 PM'.length,
          type: TemplateFieldType.date,
        ),
      ],
    );

    test('the wildcard is not a captured field', () {
      final template = build();
      expect(
        template.fieldMap.values,
        isNot(contains(TemplateFieldType.wildcard)),
      );
      expect(template.readsOwnSample, isTrue);
    });

    test('a different reference still matches', () {
      final r = Parser.parse(second, [build()], currencyCode: 'KES');
      expect(r.matched, isTrue);
      expect(r.fields!.amountMinor, 125000);
      expect(r.fields!.counterparty, 'JANE DOE');
      expect(r.fields!.occurredAt, DateTime(2026, 10, 5, 9, 15));
    });
  });

  test('a wildcard as the last label matches the rest of the line', () {
    const sample = 'Paid KES 100 to JOHN at the market';
    final template = CaptureTemplate.fromLabeledSample(
      id: 't',
      unitId: 'u',
      name: 'trailing wildcard',
      direction: TemplateDirection.spent,
      sampleText: sample,
      labels: [
        LabeledSpan(
          start: sample.indexOf('KES 100'),
          end: sample.indexOf('KES 100') + 'KES 100'.length,
          type: TemplateFieldType.amount,
        ),
        LabeledSpan(
          start: sample.indexOf('JOHN'),
          end: sample.indexOf('JOHN') + 'JOHN'.length,
          type: TemplateFieldType.person,
        ),
        LabeledSpan(
          start: sample.indexOf('the market'),
          end: sample.length,
          type: TemplateFieldType.wildcard,
        ),
      ],
    );

    final r = Parser.parse(
      'Paid KES 250 to JANE at a different place',
      [template],
      currencyCode: 'KES',
    );
    expect(r.matched, isTrue);
    expect(r.fields!.amountMinor, 25000);
    expect(r.fields!.counterparty, 'JANE');
  });
}
