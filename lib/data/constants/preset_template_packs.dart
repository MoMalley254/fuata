// ---------------------------------------------------------------------------
// Bundled preset template packs (issue #34).
//
// Each pack is built with `CaptureTemplate.fromLabeledSample` — the exact
// mechanism the rule builder uses to make a rule from a pasted sample.
// The presets are therefore not a special case anywhere downstream: they
// produce the same `pattern` + `fieldMap` a user would produce by hand,
// and the parser treats them identically.
//
// Samples are drawn from the shapes the parser tests already use
// (test/fixtures/messages.dart). If a preset's sample and the fixture
// drift apart, `test/data/constants/preset_template_packs_test.dart`
// catches it — that test is the reason the samples can't quietly rot.
//
// `suggestedPackage` is a hint. For most Fuata users the SMS app
// (`com.android.mms` or `com.google.android.apps.messaging`) is what's
// on their allow-list, and the pack's templates get bound to nothing —
// match any allowed source. That's correct. The hint only helps those
// who have a specific banking app enabled.
// ---------------------------------------------------------------------------
import '../../domain/models/template.dart';
import '../../domain/models/template_pack.dart';

PackTemplate _build({
  required String name,
  required TemplateDirection direction,
  required String sample,
  required List<(String, TemplateFieldType)> labels,
}) {
  final spans = [
    for (final (text, type) in labels)
      LabeledSpan(
        start: sample.indexOf(text),
        end: sample.indexOf(text) + text.length,
        type: type,
      ),
  ];
  final built = CaptureTemplate.fromLabeledSample(
    id: 'unused',
    unitId: 'unused',
    name: name,
    direction: direction,
    sampleText: sample,
    labels: spans,
  );
  return PackTemplate(
    name: name,
    direction: direction,
    pattern: built.pattern,
    fieldMap: built.fieldMap,
    sampleText: sample,
  );
}

// The sample strings, checked against test/fixtures/messages.dart by the
// preset test. Kept private so callers don't reach for them by accident —
// the *pack* is the public surface, not the sample.

const _mpesaSent =
    'UIS9P8GJV5 Confirmed. Ksh500.00 sent to JOHN DOE 0712345678 on '
    '28/9/26 at 11:03 PM. New M-PESA balance is Ksh1,234.56. '
    'Transaction cost, Ksh7.00.';

const _mpesaReceived =
    'UIS9P8GK01 Confirmed. You have received Ksh1,000.00 from JANE DOE '
    '0722000000 on 28/9/26 at 9:15 AM. New M-PESA balance is Ksh2,234.56.';

const _mpesaPaybill =
    'UIS9P8GK02 Confirmed. Ksh1,200.00 sent to KPLC PREPAID for account '
    '12345678 on 28/9/26 at 10:00 AM. New M-PESA balance is Ksh1,034.56. '
    'Transaction cost, Ksh0.00.';

const _mpesaTill =
    'UIS9P8GK03 Confirmed. Ksh350.00 paid to SUPERMARKET LTD. on '
    '28/9/26 at 1:12 PM. New M-PESA balance is Ksh684.56.';

const _mpesaAgent =
    'UIS9P8GK04 Confirmed. on 28/9/26 at 4:10 PM Withdraw Ksh2,000.00 '
    'from 123456 - AGENT NAME New M-PESA balance is Ksh500.00.';

const _fuliza =
    'UIS9P8GK05 Confirmed. Fuliza M-PESA amount is Ksh100.00. Interest '
    'charged Ksh1.00. Total Fuliza balance is Ksh400.00.';

const _airtel =
    'Txn ID XYZ123. You have sent KES 500 to PETER OTIENO 0733445566. '
    'Bal KES 4,500.';

const _bankDebit =
    'Acct: XXXX1234 debited KES 1,500.00 on 28-Sep-26 Ref TXN-45/B. '
    'Bal: KES 8,500.00.';

const _card =
    'Card ending 1234 used for KES 2,300.00 at SOME SHOP on '
    '28/09/2026 14:05.';

const _salary =
    'Your account has been credited with KES 85,000.00 on 25/9/26. '
    'Ref SAL09/26. Bal KES 90,000.00.';

final presetTemplatePacks = <TemplatePack>[
  TemplatePack(
    id: 'mpesa_ke',
    name: 'M-PESA Kenya',
    description:
    'The most common M-PESA messages: money out, money in, paybill, '
        'till payments, agent withdrawals and Fuliza.',
    // The M-PESA app is `com.safaricom.mpesa` on newer installs; older
    // users only ever see M-PESA via SMS, which is caught through the
    // messages app. Left as a hint.
    suggestedPackage: 'com.safaricom.mpesa',
    isPreset: true,
    templates: [
      _build(
        name: 'M-PESA · money out',
        direction: TemplateDirection.spent,
        sample: _mpesaSent,
        labels: const [
          ('UIS9P8GJV5', TemplateFieldType.code),
          ('Ksh500.00', TemplateFieldType.amount),
          ('JOHN DOE 0712345678', TemplateFieldType.person),
          ('28/9/26 at 11:03 PM', TemplateFieldType.date),
          ('Ksh1,234.56', TemplateFieldType.balance),
          ('Ksh7.00', TemplateFieldType.fee),
        ],
      ),
      _build(
        name: 'M-PESA · money in',
        direction: TemplateDirection.either,
        sample: _mpesaReceived,
        labels: const [
          ('UIS9P8GK01', TemplateFieldType.code),
          ('Ksh1,000.00', TemplateFieldType.amount),
          ('JANE DOE 0722000000', TemplateFieldType.person),
          ('28/9/26 at 9:15 AM', TemplateFieldType.date),
          ('Ksh2,234.56', TemplateFieldType.balance),
        ],
      ),
      _build(
        name: 'M-PESA · paybill',
        direction: TemplateDirection.spent,
        sample: _mpesaPaybill,
        labels: const [
          ('UIS9P8GK02', TemplateFieldType.code),
          ('Ksh1,200.00', TemplateFieldType.amount),
          ('KPLC PREPAID', TemplateFieldType.person),
          ('28/9/26 at 10:00 AM', TemplateFieldType.date),
          ('Ksh1,034.56', TemplateFieldType.balance),
          ('Ksh0.00', TemplateFieldType.fee),
        ],
      ),
      _build(
        name: 'M-PESA · till',
        direction: TemplateDirection.spent,
        sample: _mpesaTill,
        labels: const [
          ('UIS9P8GK03', TemplateFieldType.code),
          ('Ksh350.00', TemplateFieldType.amount),
          ('SUPERMARKET LTD', TemplateFieldType.person),
          ('28/9/26 at 1:12 PM', TemplateFieldType.date),
          ('Ksh684.56', TemplateFieldType.balance),
        ],
      ),
      _build(
        name: 'M-PESA · agent withdrawal',
        direction: TemplateDirection.spent,
        sample: _mpesaAgent,
        labels: const [
          ('UIS9P8GK04', TemplateFieldType.code),
          ('28/9/26 at 4:10 PM', TemplateFieldType.date),
          ('Ksh2,000.00', TemplateFieldType.amount),
          ('123456 - AGENT NAME', TemplateFieldType.person),
          ('Ksh500.00', TemplateFieldType.balance),
        ],
      ),
      _build(
        name: 'Fuliza',
        direction: TemplateDirection.spent,
        sample: _fuliza,
        labels: const [
          ('UIS9P8GK05', TemplateFieldType.code),
          ('Ksh100.00', TemplateFieldType.amount),
          ('Ksh1.00', TemplateFieldType.fee),
        ],
      ),
    ],
  ),
  TemplatePack(
    id: 'airtel_ke',
    name: 'Airtel Money Kenya',
    description: 'Airtel Money sent and received messages.',
    suggestedPackage: 'com.airtel.money',
    isPreset: true,
    templates: [
      _build(
        name: 'Airtel · money out',
        direction: TemplateDirection.spent,
        sample: _airtel,
        labels: const [
          ('XYZ123', TemplateFieldType.code),
          ('KES 500', TemplateFieldType.amount),
          ('PETER OTIENO 0733445566', TemplateFieldType.person),
          ('KES 4,500', TemplateFieldType.balance),
        ],
      ),
    ],
  ),
  TemplatePack(
    id: 'kenyan_banks',
    name: 'Kenyan banks',
    description:
    'Generic bank debit, card and salary-credit messages. A starting '
        'point — most banks use slightly different wording, so expect to '
        'edit the pattern after the first message arrives.',
    isPreset: true,
    templates: [
      _build(
        name: 'Bank · debit alert',
        direction: TemplateDirection.spent,
        sample: _bankDebit,
        labels: const [
          ('KES 1,500.00', TemplateFieldType.amount),
          ('28-Sep-26', TemplateFieldType.date),
          ('TXN-45/B', TemplateFieldType.code),
          ('KES 8,500.00', TemplateFieldType.balance),
        ],
      ),
      _build(
        name: 'Card · purchase',
        direction: TemplateDirection.spent,
        sample: _card,
        labels: const [
          ('KES 2,300.00', TemplateFieldType.amount),
          ('SOME SHOP', TemplateFieldType.person),
          ('28/09/2026 14:05', TemplateFieldType.date),
        ],
      ),
      _build(
        name: 'Bank · salary credit',
        direction: TemplateDirection.either,
        sample: _salary,
        labels: const [
          ('KES 85,000.00', TemplateFieldType.amount),
          ('25/9/26', TemplateFieldType.date),
          ('SAL09/26', TemplateFieldType.code),
          ('KES 90,000.00', TemplateFieldType.balance),
        ],
      ),
    ],
  ),
];