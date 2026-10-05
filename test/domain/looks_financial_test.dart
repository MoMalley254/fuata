import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/looks_financial.dart';

void main() {
  group('LooksFinancial.check — financial signals', () {
    test('a currency token alone is enough', () {
      expect(LooksFinancial.check('You received KES 500'), isTrue);
      expect(LooksFinancial.check('Paid Ksh350 to Java House'), isTrue);
      expect(LooksFinancial.check('KSH 100 from mum'), isTrue);
      expect(LooksFinancial.check('Sent 2000/='), isTrue);
    });

    test('an amount with a money shape near a money word', () {
      expect(LooksFinancial.check('Paid 1,500 to Naivas'), isTrue);
      expect(LooksFinancial.check('Balance is 1234.56'), isTrue);
      expect(LooksFinancial.check('You sent 500.00'), isTrue);
    });

    test('a real M-PESA-shaped message', () {
      expect(
        LooksFinancial.check(
          'UIS9P8GJV5 Confirmed. Ksh500.00 sent to JOHN DOE 0712345678 '
              'on 28/9/26 at 11:03 PM. New M-PESA balance is Ksh1,234.56.',
        ),
        isTrue,
      );
    });
  });

  group('LooksFinancial.check — not financial', () {
    test('a plain chat message', () {
      expect(LooksFinancial.check('Hey, are we still on for 3?'), isFalse);
      expect(LooksFinancial.check('3 new messages'), isFalse);
      expect(LooksFinancial.check('Your delivery is on its way'), isFalse);
    });

    test('empty and whitespace', () {
      expect(LooksFinancial.check(''), isFalse);
      expect(LooksFinancial.check('   '), isFalse);
    });

    test('a bare integer with no currency and no money word', () {
      expect(LooksFinancial.check('Order 12345 shipped'), isFalse);
    });

    test('a bare integer near a money word but with no money shape', () {
      // "1200" has neither a comma nor decimals.
      expect(LooksFinancial.check('Please pay 1200'), isFalse);
    });

    test('a word that merely looks like a currency', () {
      // KESHO is Swahili for tomorrow and shouldn't match KSH.
      expect(LooksFinancial.check('Tutaonana kesho!'), isFalse);
    });
  });

  group('LooksFinancial.check — one-time codes always drop', () {
    test('an OTP with no financial signal at all', () {
      expect(LooksFinancial.check('Your OTP is 123456'), isFalse);
      expect(LooksFinancial.check('Verification code: 456789'), isFalse);
      expect(LooksFinancial.check('PIN 1234'), isFalse);
    });

    test('an OTP that also looks financial', () {
      expect(
        LooksFinancial.check('Code 456789. Card purchase KES 2,300.00'),
        isFalse,
      );
      expect(
        LooksFinancial.check(
          'Verify with 1234 to confirm the 1,500.00 transfer',
        ),
        isFalse,
      );
    });
  });

}