import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/amount_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const needNumber = '금액은 숫자로 입력하세요. (달러 단위, 소수점 없음)';
  const atLeastOne = '금액은 1달러 이상이어야 합니다.';
  const tooBig = '금액은 21,474,836달러 이하여야 합니다.';

  group('validateDollars', () {
    test('whole dollars from 1 to 21,474,836 are fine', () {
      for (final ok in ['1', '5', ' 7 ', '007', '9999999', '21474836']) {
        expect(validateDollars(ok), isNull, reason: ok);
      }
    });

    test('empty is refused', () {
      expect(validateDollars(''), '금액을 입력하세요.');
      expect(validateDollars('   '), '금액을 입력하세요.');
      expect(validateDollars(null), '금액을 입력하세요.');
    });

    test('zero and negative amounts are refused', () {
      for (final bad in ['0', '00', '-0', '-1', '-10', '-9999999', '-99999999999999999999']) {
        expect(validateDollars(bad), atLeastOne, reason: bad);
      }
    });

    test('anything but digits is refused (hex, plus sign, exponent, decimals, commas)', () {
      for (final bad in ['0x10', '0X1F', '+5', '1e2', '5.0', '12.5', '1,000', '٥', 'abc', '1 0', '--5', '5-']) {
        expect(validateDollars(bad), needNumber, reason: bad);
      }
    });

    test('too big is refused, also when it does not fit in a number', () {
      expect(validateDollars('21474837'), tooBig);
      expect(validateDollars('10000000'), isNull); // the old limit of the app is gone
      expect(validateDollars('99999999999999999999'), tooBig);
    });
  });
}
