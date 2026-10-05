import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/transaction.dart';

// Issue #72 / issue-26 F11e. Shapes approximate the Kenyan bank and
// mobile-money messages the app has to read; every name, number and amount
// is made up. Replace each with a redacted real message from a real phone
// when one is to hand (the second message of each pair must stay the same
// shape with different values: that is the real test that a rule
// generalises).

/// What reading a message should give. Only the fields a fixture labels
/// are set.
class Expected {
  final TxType type;
  final int amountMinor;
  final String? person;
  final String? code;
  final DateTime? date;
  final int? feeMinor;
  final int? balanceMinor;
  const Expected({
    required this.type,
    required this.amountMinor,
    this.person,
    this.code,
    this.date,
    this.feeMinor,
    this.balanceMinor,
  });
}

class MessageFixture {
  final String id;
  final String name;
  final TemplateDirection direction;
  final String sample;

  /// (field type, the exact text in [sample] to label). Each text must
  /// appear in [sample] and be unique enough for `indexOf` to find the
  /// intended occurrence.
  final List<(TemplateFieldType, String)> labels;
  final Expected expectedForSample;

  /// Same shape as [sample], different name, amount, date and code.
  final String second;
  final Expected expectedForSecond;
  const MessageFixture({
    required this.id,
    required this.name,
    required this.direction,
    required this.sample,
    required this.labels,
    required this.expectedForSample,
    required this.second,
    required this.expectedForSecond,
  });
}

const coopWarning =
    'Please NEVER share your PIN, PASSWORD, any codes or CARD details with '
    'ANYONE! not even people who may claim to be bank staff. ';

/// Messages that look like the M-PESA sent fixture but must never become a
/// transaction when read with its rule.
const notASentTransaction = [
  'QRT7Y6U5I9 Failed. Ksh500.00 not sent to JOHN DOE 0712345678 on 28/9/26 at 11:03 PM.',
  'QRT7Y6U5J2 Transaction reversed. Ksh500.00 returned from JOHN DOE 0712345678 on 28/9/26 at 11:03 PM.',
];

final messageFixtures = <MessageFixture>[
  MessageFixture(
    id: 'coop',
    name: 'Co-op transfer',
    direction: TemplateDirection.spent,
    sample: coopWarning + 'Ref:AC4368F03026: Dear MORRIS, MPESA transfer of KES 500 to MORRIS KINYUA NJUGUNA-0743230001 at 28-09-2026 11:03 PM was successful.MPESA Ref:UIS9P8GJV5.',
    labels: [
      (TemplateFieldType.code, 'Ref:AC4368F03026'),
      (TemplateFieldType.amount, 'KES 500'),
      (TemplateFieldType.person, 'MORRIS KINYUA NJUGUNA-0743230001'),
      (TemplateFieldType.date, '28-09-2026 11:03 PM'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 50000, person: 'MORRIS KINYUA NJUGUNA-0743230001', code: 'Ref:AC4368F03026', date: DateTime(2026, 9, 28, 23, 3)),
    second: coopWarning + 'Ref:ZX9911223344: Dear MORRIS, MPESA transfer of KES 1,250 to JANE WANJIKU MWANGI-0711000222 at 05-10-2026 09:15 AM was successful.MPESA Ref:QWE1R2T3Y4.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 125000, person: 'JANE WANJIKU MWANGI-0711000222', code: 'Ref:ZX9911223344', date: DateTime(2026, 10, 5, 9, 15)),
  ),
  MessageFixture(
    id: 'mpesa_sent',
    name: 'M-PESA sent',
    direction: TemplateDirection.spent,
    sample: 'UIS9P8GJV5 Confirmed. Ksh500.00 sent to JOHN DOE 0712345678 on 28/9/26 at 11:03 PM. New M-PESA balance is Ksh1,234.56. Transaction cost, Ksh7.00.',
    labels: [
      (TemplateFieldType.code, 'UIS9P8GJV5'),
      (TemplateFieldType.amount, 'Ksh500.00'),
      (TemplateFieldType.person, 'JOHN DOE 0712345678'),
      (TemplateFieldType.date, '28/9/26 at 11:03 PM'),
      (TemplateFieldType.balance, 'Ksh1,234.56'),
      (TemplateFieldType.fee, 'Ksh7.00'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 50000, person: 'JOHN DOE 0712345678', code: 'UIS9P8GJV5', date: DateTime(2026, 9, 28, 23, 3), feeMinor: 700, balanceMinor: 123456),
    second: 'QRT7Y6U5I4 Confirmed. Ksh1,250.00 sent to JANE WANJIKU 0722000111 on 5/10/26 at 9:15 AM. New M-PESA balance is Ksh8,100.50. Transaction cost, Ksh13.00.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 125000, person: 'JANE WANJIKU 0722000111', code: 'QRT7Y6U5I4', date: DateTime(2026, 10, 5, 9, 15), feeMinor: 1300, balanceMinor: 810050),
  ),
  MessageFixture(
    id: 'mpesa_received',
    name: 'M-PESA received',
    direction: TemplateDirection.either,
    sample: 'UIS9P8GK01 Confirmed. You have received Ksh1,000.00 from JANE DOE 0722000000 on 28/9/26 at 9:15 AM. New M-PESA balance is Ksh2,234.56.',
    labels: [
      (TemplateFieldType.code, 'UIS9P8GK01'),
      (TemplateFieldType.amount, 'Ksh1,000.00'),
      (TemplateFieldType.person, 'JANE DOE 0722000000'),
      (TemplateFieldType.date, '28/9/26 at 9:15 AM'),
      (TemplateFieldType.balance, 'Ksh2,234.56'),
    ],
    expectedForSample: Expected(type: TxType.got, amountMinor: 100000, person: 'JANE DOE 0722000000', code: 'UIS9P8GK01', date: DateTime(2026, 9, 28, 9, 15), balanceMinor: 223456),
    second: 'QWE4R5T6Y7 Confirmed. You have received Ksh2,500.00 from PETER KAMAU 0733111222 on 6/10/26 at 3:40 PM. New M-PESA balance is Ksh9,999.00.',
    expectedForSecond: Expected(type: TxType.got, amountMinor: 250000, person: 'PETER KAMAU 0733111222', code: 'QWE4R5T6Y7', date: DateTime(2026, 10, 6, 15, 40), balanceMinor: 999900),
  ),
  MessageFixture(
    id: 'mpesa_paybill',
    name: 'M-PESA paybill',
    direction: TemplateDirection.spent,
    sample: 'UIS9P8GK02 Confirmed. Ksh1,200.00 sent to KPLC PREPAID for account 12345678 on 28/9/26 at 10:00 AM. New M-PESA balance is Ksh1,034.56. Transaction cost, Ksh0.00.',
    labels: [
      (TemplateFieldType.code, 'UIS9P8GK02'),
      (TemplateFieldType.amount, 'Ksh1,200.00'),
      (TemplateFieldType.person, 'KPLC PREPAID'),
      (TemplateFieldType.date, '28/9/26 at 10:00 AM'),
      (TemplateFieldType.balance, 'Ksh1,034.56'),
      (TemplateFieldType.fee, 'Ksh0.00'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 120000, person: 'KPLC PREPAID', code: 'UIS9P8GK02', date: DateTime(2026, 9, 28, 10, 0), feeMinor: 0, balanceMinor: 103456),
    second: 'QRT7Y6U5I8 Confirmed. Ksh800.00 sent to NAIROBI WATER for account 12345678 on 7/10/26 at 12:30 PM. New M-PESA balance is Ksh234.56. Transaction cost, Ksh0.00.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 80000, person: 'NAIROBI WATER', code: 'QRT7Y6U5I8', date: DateTime(2026, 10, 7, 12, 30), feeMinor: 0, balanceMinor: 23456),
  ),
  MessageFixture(
    id: 'mpesa_till',
    name: 'M-PESA till',
    direction: TemplateDirection.spent,
    sample: 'UIS9P8GK03 Confirmed. Ksh350.00 paid to SUPERMARKET LTD. on 28/9/26 at 1:12 PM. New M-PESA balance is Ksh684.56.',
    labels: [
      (TemplateFieldType.code, 'UIS9P8GK03'),
      (TemplateFieldType.amount, 'Ksh350.00'),
      (TemplateFieldType.person, 'SUPERMARKET LTD'),
      (TemplateFieldType.date, '28/9/26 at 1:12 PM'),
      (TemplateFieldType.balance, 'Ksh684.56'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 35000, person: 'SUPERMARKET LTD', code: 'UIS9P8GK03', date: DateTime(2026, 9, 28, 13, 12), balanceMinor: 68456),
    second: 'QRT7Y6U5J1 Confirmed. Ksh1,100.00 paid to JAVA HOUSE LTD. on 7/10/26 at 8:05 AM. New M-PESA balance is Ksh2,000.00.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 110000, person: 'JAVA HOUSE LTD', code: 'QRT7Y6U5J1', date: DateTime(2026, 10, 7, 8, 5), balanceMinor: 200000),
  ),
  MessageFixture(
    id: 'mpesa_agent',
    name: 'M-PESA agent withdrawal',
    direction: TemplateDirection.spent,
    sample: 'UIS9P8GK04 Confirmed. on 28/9/26 at 4:10 PM Withdraw Ksh2,000.00 from 123456 - AGENT NAME New M-PESA balance is Ksh500.00.',
    labels: [
      (TemplateFieldType.code, 'UIS9P8GK04'),
      (TemplateFieldType.date, '28/9/26 at 4:10 PM'),
      (TemplateFieldType.amount, 'Ksh2,000.00'),
      (TemplateFieldType.person, '123456 - AGENT NAME'),
      (TemplateFieldType.balance, 'Ksh500.00'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 200000, person: '123456 - AGENT NAME', code: 'UIS9P8GK04', date: DateTime(2026, 9, 28, 16, 10), balanceMinor: 50000),
    second: 'QRT7Y6U5I5 Confirmed. on 7/10/26 at 11:20 AM Withdraw Ksh3,500.00 from 654321 - OTHER AGENT New M-PESA balance is Ksh1,500.00.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 350000, person: '654321 - OTHER AGENT', code: 'QRT7Y6U5I5', date: DateTime(2026, 10, 7, 11, 20), balanceMinor: 150000),
  ),
  MessageFixture(
    id: 'fuliza',
    name: 'Fuliza',
    direction: TemplateDirection.spent,
    sample: 'UIS9P8GK05 Confirmed. Fuliza M-PESA amount is Ksh100.00. Interest charged Ksh1.00. Total Fuliza balance is Ksh400.00.',
    labels: [
      (TemplateFieldType.code, 'UIS9P8GK05'),
      (TemplateFieldType.amount, 'Ksh100.00'),
      (TemplateFieldType.fee, 'Ksh1.00'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 10000, code: 'UIS9P8GK05', feeMinor: 100),
    second: 'QRT7Y6U5I6 Confirmed. Fuliza M-PESA amount is Ksh250.00. Interest charged Ksh2.50. Total Fuliza balance is Ksh900.00.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 25000, code: 'QRT7Y6U5I6', feeMinor: 250),
  ),
  MessageFixture(
    id: 'airtel',
    name: 'Airtel Money',
    direction: TemplateDirection.spent,
    sample: 'Txn ID XYZ123. You have sent KES 500 to PETER OTIENO 0733445566. Bal KES 4,500.',
    labels: [
      (TemplateFieldType.code, 'XYZ123'),
      (TemplateFieldType.amount, 'KES 500'),
      (TemplateFieldType.person, 'PETER OTIENO 0733445566'),
      (TemplateFieldType.balance, 'KES 4,500'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 50000, person: 'PETER OTIENO 0733445566', code: 'XYZ123', balanceMinor: 450000),
    second: 'Txn ID ABC987. You have sent KES 1,500 to MARY ACHIENG 0744556677. Bal KES 3,000.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 150000, person: 'MARY ACHIENG 0744556677', code: 'ABC987', balanceMinor: 300000),
  ),
  MessageFixture(
    id: 'bank_debit',
    name: 'Bank debit',
    direction: TemplateDirection.spent,
    sample: 'Acct: XXXX1234 debited KES 1,500.00 on 28-Sep-26 Ref TXN-45/B. Bal: KES 8,500.00.',
    labels: [
      (TemplateFieldType.amount, 'KES 1,500.00'),
      (TemplateFieldType.date, '28-Sep-26'),
      (TemplateFieldType.code, 'TXN-45/B'),
      (TemplateFieldType.balance, 'KES 8,500.00'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 150000, code: 'TXN-45/B', date: DateTime(2026, 9, 28, 0, 0), balanceMinor: 850000),
    second: 'Acct: XXXX1234 debited KES 320.00 on 06-Oct-26 Ref TXN-77/C. Bal: KES 8,180.00.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 32000, code: 'TXN-77/C', date: DateTime(2026, 10, 6, 0, 0), balanceMinor: 818000),
  ),
  MessageFixture(
    id: 'card',
    name: 'Card payment',
    direction: TemplateDirection.spent,
    sample: 'Card ending 1234 used for KES 2,300.00 at SOME SHOP on 28/09/2026 14:05.',
    labels: [
      (TemplateFieldType.amount, 'KES 2,300.00'),
      (TemplateFieldType.person, 'SOME SHOP'),
      (TemplateFieldType.date, '28/09/2026 14:05'),
    ],
    expectedForSample: Expected(type: TxType.spent, amountMinor: 230000, person: 'SOME SHOP', date: DateTime(2026, 9, 28, 14, 5)),
    second: 'Card ending 1234 used for KES 640.00 at BIG BAZAAR on 06/10/2026 09:30.',
    expectedForSecond: Expected(type: TxType.spent, amountMinor: 64000, person: 'BIG BAZAAR', date: DateTime(2026, 10, 6, 9, 30)),
  ),
  MessageFixture(
    id: 'salary',
    name: 'Salary credit',
    direction: TemplateDirection.either,
    sample: 'Your account has been credited with KES 85,000.00 on 25/9/26. Ref SAL09/26. Bal KES 90,000.00.',
    labels: [
      (TemplateFieldType.amount, 'KES 85,000.00'),
      (TemplateFieldType.date, '25/9/26'),
      (TemplateFieldType.code, 'SAL09/26'),
      (TemplateFieldType.balance, 'KES 90,000.00'),
    ],
    expectedForSample: Expected(type: TxType.got, amountMinor: 8500000, code: 'SAL09/26', date: DateTime(2026, 9, 25, 0, 0), balanceMinor: 9000000),
    second: 'Your account has been credited with KES 92,500.00 on 25/10/26. Ref SAL10/26. Bal KES 100,000.00.',
    expectedForSecond: Expected(type: TxType.got, amountMinor: 9250000, code: 'SAL10/26', date: DateTime(2026, 10, 25, 0, 0), balanceMinor: 10000000),
  ),
];
