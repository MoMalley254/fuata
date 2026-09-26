import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/parser.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/transaction.dart';

void main() {
  // Fake messages only (testing.md's rule for the parser plan) — none of
  // these are copied from a real provider's wording.

  const paidSample =
      'Confirmed. Ksh350.00 paid to JAVA HOUSE (Nairobi) on 21/9/26 at 1:12 PM. '
      'Code QW12ABC3. Fee Ksh5.00 charged (VAT incl.). New balance is Ksh4,500.00.';

  CaptureTemplate paidTemplate({String id = 't-paid'}) {
    int at(String needle) => paidSample.indexOf(needle);
    LabeledSpan span(String needle, TemplateFieldType type) =>
        LabeledSpan(start: at(needle), end: at(needle) + needle.length, type: type);

    return CaptureTemplate.fromLabeledSample(
      id: id,
      unitId: 'u-mpesa',
      name: 'M-Pesa paid to',
      direction: TemplateDirection.spent,
      sampleText: paidSample,
      labels: [
        span('Ksh350.00', TemplateFieldType.amount),
        span('JAVA HOUSE', TemplateFieldType.person),
        span('21/9/26 at 1:12 PM', TemplateFieldType.date),
        span('QW12ABC3', TemplateFieldType.code),
        span('Ksh5.00', TemplateFieldType.fee),
        span('Ksh4,500.00', TemplateFieldType.balance),
      ],
    );
  }

  const receivedSample =
      'You have received Ksh5,000.00 from JOHN DOE 0712345678 on 22/9/26 at 9:00 AM. '
      'New balance is Ksh9,500.00. Transaction ID AB34CD5E.';

  CaptureTemplate receivedTemplate({String id = 't-received'}) {
    int at(String needle) => receivedSample.indexOf(needle);
    LabeledSpan span(String needle, TemplateFieldType type) =>
        LabeledSpan(start: at(needle), end: at(needle) + needle.length, type: type);

    return CaptureTemplate.fromLabeledSample(
      id: id,
      unitId: 'u-mpesa',
      name: 'M-Pesa received',
      direction: TemplateDirection.got,
      sampleText: receivedSample,
      labels: [
        span('Ksh5,000.00', TemplateFieldType.amount),
        span('JOHN DOE 0712345678', TemplateFieldType.person),
        span('22/9/26 at 9:00 AM', TemplateFieldType.date),
        span('Ksh9,500.00', TemplateFieldType.balance),
        span('AB34CD5E', TemplateFieldType.code),
      ],
    );
  }

  const withdrawSample =
      'Withdraw of Ksh2,000.00 from ATM 00219 on 20/9/26 at 4:30 PM. '
      'Code WX55YZ9. New balance is Ksh100.00.';

  CaptureTemplate withdrawTemplate({String id = 't-withdraw'}) {
    int at(String needle) => withdrawSample.indexOf(needle);
    LabeledSpan span(String needle, TemplateFieldType type) =>
        LabeledSpan(start: at(needle), end: at(needle) + needle.length, type: type);

    return CaptureTemplate.fromLabeledSample(
      id: id,
      unitId: 'u-mpesa',
      name: 'M-Pesa withdraw',
      direction: TemplateDirection.spent,
      sampleText: withdrawSample,
      labels: [
        span('Ksh2,000.00', TemplateFieldType.amount),
        span('ATM 00219', TemplateFieldType.person),
        span('20/9/26 at 4:30 PM', TemplateFieldType.date),
        span('WX55YZ9', TemplateFieldType.code),
        span('Ksh100.00', TemplateFieldType.balance),
      ],
    );
  }

  group('P-01 labeled sample -> all fields, correct types', () {
    test('extracts amount, code, date, person, fee, balance', () {
      final result = Parser.parse(paidSample, [paidTemplate()], currencyCode: 'KES');

      expect(result.matched, isTrue);
      expect(result.type, TxType.spent);
      expect(result.fields!.amountMinor, 35000);
      expect(result.fields!.feeMinor, 500);
      expect(result.fields!.balanceAfterMinor, 450000);
      expect(result.fields!.code, 'QW12ABC3');
      expect(result.fields!.counterparty, 'JAVA HOUSE');
      expect(result.fields!.occurredAt, isNotNull);
      expect(result.fields!.occurredAt!.year, 2026);
      expect(result.fields!.occurredAt!.month, 9);
      expect(result.fields!.occurredAt!.day, 21);
      expect(result.fields!.occurredAt!.hour, 13); // 1:12 PM -> 13:12
      expect(result.fields!.occurredAt!.minute, 12);
    });
  });

  group('P-02 amount formats', () {
    final template = paidTemplate();

    test('"Ksh350.00" -> 35000 minor', () {
      final r = Parser.parse(paidSample, [template], currencyCode: 'KES');
      expect(r.fields!.amountMinor, 35000);
    });

    test('"KES 1,250" style balance -> correct minor units', () {
      final r = Parser.parse(paidSample, [template], currencyCode: 'KES');
      // "Ksh4,500.00" balance in the sample -> 450000 minor.
      expect(r.fields!.balanceAfterMinor, 450000);
    });

    test('bare "350" (no currency prefix) still parses', () {
      const bare = 'Sent 350 to PETER on 1/1/26. Code ZZ1.';
      final t = CaptureTemplate.fromLabeledSample(
        id: 't-bare',
        unitId: 'u1',
        name: 'bare',
        direction: TemplateDirection.spent,
        sampleText: bare,
        labels: [
          LabeledSpan(start: bare.indexOf('350'), end: bare.indexOf('350') + 3, type: TemplateFieldType.amount),
          LabeledSpan(
            start: bare.indexOf('PETER'),
            end: bare.indexOf('PETER') + 5,
            type: TemplateFieldType.person,
          ),
          LabeledSpan(start: bare.indexOf('ZZ1'), end: bare.indexOf('ZZ1') + 3, type: TemplateFieldType.code),
        ],
      );
      final r = Parser.parse(bare, [t], currencyCode: 'KES');
      expect(r.matched, isTrue);
      expect(r.fields!.amountMinor, 35000);
    });
  });

  test('P-03 different names/numbers in the varying part still match', () {
    const other =
        'Confirmed. Ksh1,250.50 paid to CARREFOUR (Nairobi) on 5/1/27 at 6:45 AM. '
        'Code ZZ99XYZ1. Fee Ksh10.00 charged (VAT incl.). New balance is Ksh900.00.';

    final result = Parser.parse(other, [paidTemplate()], currencyCode: 'KES');

    expect(result.matched, isTrue);
    expect(result.fields!.amountMinor, 125050);
    expect(result.fields!.counterparty, 'CARREFOUR');
    expect(result.fields!.code, 'ZZ99XYZ1');
    expect(result.fields!.balanceAfterMinor, 90000);
  });

  test('P-04 regex special characters in the sample are escaped, not matched as syntax', () {
    // The sample itself contains '.', '(', ')' outside the labeled spans
    // (see paidSample: "(Nairobi)", "(VAT incl.)"). Building the template
    // and re-matching the exact sample must not throw and must match.
    expect(() => paidTemplate(), returnsNormally);
    final result = Parser.parse(paidSample, [paidTemplate()], currencyCode: 'KES');
    expect(result.matched, isTrue);

    // A message with different literal punctuation in the same spots
    // must NOT be mistaken for a match against the escaped literals.
    const differentPunctuation =
        'Confirmed. Ksh350.00 paid to JAVA HOUSE [Nairobi] on 21/9/26 at 1:12 PM. '
        'Code QW12ABC3. Fee Ksh5.00 charged [VAT incl]. New balance is Ksh4,500.00.';
    final noMatch = Parser.parse(differentPunctuation, [paidTemplate()], currencyCode: 'KES');
    expect(noMatch.matched, isFalse);
  });

  test('P-05 a message matching no template returns no match', () {
    const unrelated = 'Your OTP is 445566. Do not share it with anyone.';
    final result = Parser.parse(
      unrelated,
      [paidTemplate(), receivedTemplate(), withdrawTemplate()],
      currencyCode: 'KES',
    );
    expect(result.matched, isFalse);
    expect(result.template, isNull);
    expect(result.fields, isNull);
  });

  group('P-06 multiple templates on one unit: correct template and direction chosen', () {
    final templates = [paidTemplate(), receivedTemplate(), withdrawTemplate()];

    test('received message matches the received template, type got', () {
      final r = Parser.parse(receivedSample, templates, currencyCode: 'KES');
      expect(r.matched, isTrue);
      expect(r.template!.id, 't-received');
      expect(r.type, TxType.got);
    });

    test('withdraw message matches the withdraw template, type spent', () {
      final r = Parser.parse(withdrawSample, templates, currencyCode: 'KES');
      expect(r.matched, isTrue);
      expect(r.template!.id, 't-withdraw');
      expect(r.type, TxType.spent);
    });

    test('paid message matches the paid template, type spent', () {
      final r = Parser.parse(paidSample, templates, currencyCode: 'KES');
      expect(r.matched, isTrue);
      expect(r.template!.id, 't-paid');
      expect(r.type, TxType.spent);
    });
  });

  // P-07 (same code deduped) and P-08 (deduped by unit+amount+2-minute
  // window when there's no code) both need to compare a parsed result
  // against already-stored transactions, which means repository access.
  // That's out of scope for the parser itself (design.md's ER diagram
  // has no dedupe table) — those cases are covered where the dedupe
  // check actually runs, in #21 (share/paste) and #22 (listener).

  group('P-09 date formats parse to the correct timestamp', () {
    test('"21/9/26 at 1:12 PM" style', () {
      final r = Parser.parse(paidSample, [paidTemplate()], currencyCode: 'KES');
      final d = r.fields!.occurredAt!;
      expect(DateTime(d.year, d.month, d.day, d.hour, d.minute), DateTime(2026, 9, 21, 13, 12));
    });

    test('ISO 8601 style', () {
      const isoSample = 'TXN on 2026-09-21T13:12:00 for Ksh100.00. Code ISO1.';
      final t = CaptureTemplate.fromLabeledSample(
        id: 't-iso',
        unitId: 'u1',
        name: 'iso',
        direction: TemplateDirection.spent,
        sampleText: isoSample,
        labels: [
          LabeledSpan(
            start: isoSample.indexOf('2026-09-21T13:12:00'),
            end: isoSample.indexOf('2026-09-21T13:12:00') + '2026-09-21T13:12:00'.length,
            type: TemplateFieldType.date,
          ),
          LabeledSpan(
            start: isoSample.indexOf('Ksh100.00'),
            end: isoSample.indexOf('Ksh100.00') + 'Ksh100.00'.length,
            type: TemplateFieldType.amount,
          ),
          LabeledSpan(
            start: isoSample.indexOf('ISO1'),
            end: isoSample.indexOf('ISO1') + 4,
            type: TemplateFieldType.code,
          ),
        ],
      );
      final r = Parser.parse(isoSample, [t], currencyCode: 'KES');
      expect(r.matched, isTrue);
      final d = r.fields!.occurredAt!;
      expect(DateTime(d.year, d.month, d.day, d.hour, d.minute), DateTime(2026, 9, 21, 13, 12));
    });
  });

  test('P-10 balance quoted in the message is extracted for reconciliation', () {
    // Comparing it against the computed balance and flagging the unit is
    // ledger/reconciliation logic (design.md section 3), not the
    // parser's job — the parser's contract is just to surface the value.
    final r = Parser.parse(paidSample, [paidTemplate()], currencyCode: 'KES');
    expect(r.fields!.balanceAfterMinor, 450000);
  });

  test('P-11 template round-trips through JSON with identical parse behaviour', () {
    final original = paidTemplate();
    final restored = CaptureTemplate.fromJson(original.toJson());

    expect(restored.pattern, original.pattern);
    expect(restored.fieldMap, original.fieldMap);
    expect(restored.direction, original.direction);

    final before = Parser.parse(paidSample, [original], currencyCode: 'KES');
    final after = Parser.parse(paidSample, [restored], currencyCode: 'KES');

    expect(after.matched, before.matched);
    expect(after.fields!.amountMinor, before.fields!.amountMinor);
    expect(after.fields!.code, before.fields!.code);
    expect(after.fields!.counterparty, before.fields!.counterparty);
    expect(after.fields!.balanceAfterMinor, before.fields!.balanceAfterMinor);
  });

  group('P-12 very long or empty message does not crash', () {
    final templates = [paidTemplate(), receivedTemplate(), withdrawTemplate()];

    test('empty message', () {
      expect(() => Parser.parse('', templates, currencyCode: 'KES'), returnsNormally);
      expect(Parser.parse('', templates, currencyCode: 'KES').matched, isFalse);
    });

    test('very long message', () {
      final long = 'Random noise. ' * 5000;
      expect(() => Parser.parse(long, templates, currencyCode: 'KES'), returnsNormally);
      expect(Parser.parse(long, templates, currencyCode: 'KES').matched, isFalse);
    });

    test('very long message that still contains a real match', () {
      final long = '${'Random noise. ' * 2000}$paidSample${' more noise' * 2000}';
      final r = Parser.parse(long, templates, currencyCode: 'KES');
      expect(r.matched, isTrue);
      expect(r.fields!.amountMinor, 35000);
    });
  });
}