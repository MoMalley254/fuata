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
  // Labels are listed in message order, so a running cursor lets a later
  // label with the *same* text (e.g. "Ksh0.00" for balance and again for
  // fee) find its own occurrence instead of re-labelling the first one.
  // Without this, presets whose samples contain a duplicated string
  // produced two spans at the same offsets and blew up
  // CaptureTemplate.fromLabeledSample's non-overlap assertion.
  final spans = <LabeledSpan>[];
  var cursor = 0;
  for (final (text, type) in labels) {
    final at = sample.indexOf(text, cursor);
    if (at < 0) {
      throw StateError(
        'Preset "$name": label "$text" not found in its sample at or '
        'after position $cursor.',
      );
    }
    spans.add(LabeledSpan(start: at, end: at + text.length, type: type));
    // Advance so the next label can never re-label this same text.
    cursor = at + text.length;
  }

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
    customFieldNames: built.customFieldNames,
  );
}

// The sample strings, checked against test/fixtures/messages.dart by the
// preset test. Kept private so callers don't reach for them by accident —
// the *pack* is the public surface, not the sample.

//Mpesa messages updated 25/10/26

const _mpesaSent =
    'UJM9PBCOXY Confirmed. Ksh50.00 sent to JOHN DOE 0712345678 on '
    '22/10/26 at 7:34 PM. New M-PESA balance is Ksh0.00. Transaction '
    'cost, Ksh0.00.  Amount you can transact within the day is 499,700.00. '
    'See all your balances now https://saf.cx/iqIzU';

const _mpesaReceived =
    'UJPEFB33DA Confirmed.You have received Ksh50.00 from JOHN DOE '
    '0712345678 on 25/10/26 at 10:16 AM  New M-PESA balance is '
    'Ksh50.00. Invest & earn daily interest with ZIIDI on '
    'https://saf.cx/cF6ir';

const _mpesaPaybill =
    'UJO9PBMZKR Confirmed. Ksh50.00 sent to ZURI GENESIS CO LTD for '
    'account 289 on 24/10/26 at 10:58 PM New M-PESA balance is Ksh0.00. '
    'Transaction cost, Ksh0.00.Amount you can transact within the day is '
    '499,850.00. See all your balances now https://saf.cx/kWQpy';

const _mpesaTill =
    'UJP69BDHKE Confirmed. Ksh80.00 paid to AHADI WIRELESS-KONNECT '
    'INTERNET. on 25/10/26 at 1:44 AM.New M-PESA balance is Ksh186.24. '
    'Transaction cost, Ksh0.00. Amount you can transact within the day is '
    '499,920.00. See all your balances now https://saf.cx/kWQpy';

const _mpesaAgent =
    'UIS9P8GK04 Confirmed. on 28/9/26 at 4:10 PM Withdraw Ksh2,000.00 '
    'from 123456 - AGENT NAME New M-PESA balance is Ksh500.00.';

const _fuliza =
    'UJP9PBNNZ3\n Confirmed. Ksh 50.00 from your M-PESA has been used to '
    'partially pay your outstanding Fuliza M-PESA. Your available Fuliza '
    'M-PESA limit is Ksh 66.22. Your M-PESA balance is 0.00.';

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
          ('UJM9PBCOXY', TemplateFieldType.code),
          ('Ksh50.00', TemplateFieldType.amount),
          ('JOHN DOE 0712345678', TemplateFieldType.person),
          ('22/10/26 at 7:34 PM', TemplateFieldType.date),
          ('Ksh0.00', TemplateFieldType.balance),
          ('Ksh0.00', TemplateFieldType.fee),
        ],
      ),
      _build(
        name: 'M-PESA · money in',
        direction: TemplateDirection.either,
        sample: _mpesaReceived,
        labels: const [
          ('UJPEFB33DA', TemplateFieldType.code),
          ('Ksh50.00', TemplateFieldType.amount),
          ('JOHN DOE 0712345678', TemplateFieldType.person),
          ('25/10/26 at 10:16 AM', TemplateFieldType.date),
          ('Ksh50.00', TemplateFieldType.balance),
        ],
      ),
      _build(
        name: 'M-PESA · paybill',
        direction: TemplateDirection.spent,
        sample: _mpesaPaybill,
        labels: const [
          ('UJO9PBMZKR', TemplateFieldType.code),
          ('Ksh50.00', TemplateFieldType.amount),
          ('ZURI GENESIS CO LTD', TemplateFieldType.person),
          ('24/10/26 at 10:58 PM', TemplateFieldType.date),
          ('Ksh0.00', TemplateFieldType.balance),
          ('Ksh0.00', TemplateFieldType.fee),
        ],
      ),
      _build(
        name: 'M-PESA · till',
        direction: TemplateDirection.spent,
        sample: _mpesaTill,
        labels: const [
          ('UJP69BDHKE', TemplateFieldType.code),
          ('Ksh80.00', TemplateFieldType.amount),
          ('AHADI WIRELESS-KONNECT INTERNET', TemplateFieldType.person),
          ('25/10/26 at 1:44 AM', TemplateFieldType.date),
          ('Ksh186.24', TemplateFieldType.balance),
          ('Ksh0.00', TemplateFieldType.fee),
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
          ('UJP9PBNNZ3', TemplateFieldType.code),
          ('Ksh 50.00', TemplateFieldType.amount),
          ('0.00', TemplateFieldType.balance),
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
