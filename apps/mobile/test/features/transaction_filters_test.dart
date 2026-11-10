import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_filters.dart';
import 'package:flutter_test/flutter_test.dart';

DateBox box(String y, String m, String d) => DateBox(year: y, month: m, day: d);

void main() {
  group('buildDateRange', () {
    test('two empty boxes mean no filter', () {
      final r = buildDateRange(const DateBox(), const DateBox());
      expect(r.ok, isTrue);
      expect(r.empty, isTrue);
    });

    test('the start is the first moment of its day, the end the last moment of its day', () {
      final r = buildDateRange(box('2026', '03', '05'), box('2026', '03', '09'));
      expect(r.ok, isTrue);
      expect(r.empty, isFalse);
      expect(r.start, DateTime(2026, 3, 5));
      expect(r.end, DateTime(2026, 3, 9, 23, 59, 59, 999));
    });

    test('one digit for the month and the day is fine', () {
      final r = buildDateRange(box('2026', '3', '5'), box('2026', '3', '9'));
      expect(r.start, DateTime(2026, 3, 5));
    });

    test('only a start means from that day on', () {
      final r = buildDateRange(box('2026', '03', '05'), const DateBox());
      expect(r.ok, isTrue);
      expect(r.start, DateTime(2026, 3, 5));
      expect(r.end, isNull);
    });

    test('only an end means up to that day', () {
      final r = buildDateRange(const DateBox(), box('2026', '03', '09'));
      expect(r.ok, isTrue);
      expect(r.start, isNull);
      expect(r.end, DateTime(2026, 3, 9, 23, 59, 59, 999));
    });

    test('the same day twice is fine and means that whole day', () {
      final r = buildDateRange(box('2026', '03', '05'), box('2026', '03', '05'));
      expect(r.ok, isTrue);
      expect(r.start, DateTime(2026, 3, 5));
      expect(r.end, DateTime(2026, 3, 5, 23, 59, 59, 999));
    });

    test('a start day after the end day is refused, and both boxes are marked', () {
      final r = buildDateRange(box('2026', '03', '10'), box('2026', '03', '09'));
      expect(r.ok, isFalse);
      expect(r.error, DateRangeError.order);
      expect(r.boxes, [DateBoxName.start, DateBoxName.end]);
    });

    test('a box with only some fields is incomplete, and only that box is marked', () {
      final r = buildDateRange(box('2026', '', ''), const DateBox());
      expect(r.error, DateRangeError.incomplete);
      expect(r.boxes, [DateBoxName.start]);
      expect(buildDateRange(const DateBox(), box('', '03', '')).boxes, [DateBoxName.end]);
    });

    test('the year needs 4 digits, the month and the day 1 or 2', () {
      for (final bad in [box('26', '03', '05'), box('20266', '03', '05'), box('2026', '003', '05'), box('2026', '03', '005'), box('20a6', '03', '05')]) {
        expect(buildDateRange(bad, const DateBox()).error, DateRangeError.format, reason: '${bad.year}/${bad.month}/${bad.day}');
      }
    });

    test('days that do not exist are refused', () {
      for (final bad in [box('2026', '02', '30'), box('2026', '13', '01'), box('2026', '00', '10'), box('2026', '04', '31'), box('2026', '02', '29')]) {
        expect(buildDateRange(bad, const DateBox()).error, DateRangeError.invalidDate, reason: '${bad.year}/${bad.month}/${bad.day}');
      }
      // A leap day is a real day.
      expect(buildDateRange(box('2028', '02', '29'), const DateBox()).ok, isTrue);
    });

    test('when both boxes are wrong, both are marked', () {
      final r = buildDateRange(box('2026', '02', '30'), box('2026', '', ''));
      expect(r.ok, isFalse);
      expect(r.boxes, [DateBoxName.start, DateBoxName.end]);
    });
  });

  group('dateRangeErrorText', () {
    test('names the box that is wrong', () {
      expect(dateRangeErrorText(DateRangeError.incomplete, [DateBoxName.start]), '시작일의 연·월·일을 모두 입력하세요');
      expect(dateRangeErrorText(DateRangeError.incomplete, [DateBoxName.end]), '종료일의 연·월·일을 모두 입력하세요');
      expect(dateRangeErrorText(DateRangeError.invalidDate, [DateBoxName.start, DateBoxName.end]), '시작일과 종료일: 존재하지 않는 날짜입니다');
      expect(dateRangeErrorText(DateRangeError.format, [DateBoxName.end]), '종료일: 연도는 4자리, 월·일은 1~2자리 숫자로 입력하세요');
      expect(dateRangeErrorText(DateRangeError.order, [DateBoxName.start, DateBoxName.end]), '시작일이 종료일보다 늦을 수 없습니다');
    });
  });

  group('parseDollarRange', () {
    test('two empty boxes mean no filter', () {
      expect(parseDollarRange('', '').empty, isTrue);
      expect(parseDollarRange('  ', ' ').empty, isTrue);
    });

    test('a minimum and a maximum are cents', () {
      final r = parseDollarRange('10', '20');
      expect(r.ok, isTrue);
      expect(r.minCents, 1000);
      expect(r.maxCents, 2000);
    });

    test('an empty minimum means 0, an empty maximum means no limit', () {
      final onlyMax = parseDollarRange('', '50');
      expect(onlyMax.minCents, 0);
      expect(onlyMax.maxCents, 5000);
      final onlyMin = parseDollarRange('5', '');
      expect(onlyMin.minCents, 500);
      expect(onlyMin.maxCents, isNull);
    });

    test('the same number twice is fine: exactly that amount', () {
      final r = parseDollarRange('100', '100');
      expect(r.ok, isTrue);
      expect(r.minCents, 10000);
      expect(r.maxCents, 10000);
    });

    test('a minimum above the maximum is refused (1000 ~ 100)', () {
      final r = parseDollarRange('1000', '100');
      expect(r.ok, isFalse);
      expect(r.error, DollarRangeError.order);
      expect(parseDollarRange('101', '100').error, DollarRangeError.order);
    });

    test('only digits are fine, with or without commas', () {
      expect(parseDollarRange('1,000', '2,500').maxCents, 250000);
      for (final bad in ['abc', '1.5', '-5', '+5', '1e3', '0x10', '1 0']) {
        expect(parseDollarRange(bad, '').error, DollarRangeError.format, reason: bad);
        expect(parseDollarRange('', bad).error, DollarRangeError.format, reason: bad);
      }
    });

    test('above 21,474,836 dollars is refused, also when the number is huge', () {
      expect(parseDollarRange('', '21474836').ok, isTrue);
      expect(parseDollarRange('', '21474837').error, DollarRangeError.tooLarge);
      expect(parseDollarRange('21474837', '').error, DollarRangeError.tooLarge);
      expect(parseDollarRange('', '99999999999999999999').error, DollarRangeError.tooLarge);
    });

    test('a zero minimum is a real filter (0 and up)', () {
      final r = parseDollarRange('0', '');
      expect(r.empty, isFalse);
      expect(r.minCents, 0);
    });
  });

  group('texts', () {
    test('error texts', () {
      expect(dollarRangeErrorText(DollarRangeError.format), '숫자(정수)만 입력하세요');
      expect(dollarRangeErrorText(DollarRangeError.tooLarge), '21,474,836 이하로 입력하세요');
      expect(dollarRangeErrorText(DollarRangeError.order), '최소 금액이 최대 금액보다 클 수 없습니다');
    });

    test('the chip label', () {
      expect(amountRangeLabel(null, null), '전체');
      expect(amountRangeLabel(500, null), '\$5 이상');
      expect(amountRangeLabel(0, null), '\$0 이상');
      expect(amountRangeLabel(0, 5000), '\$0 ~ \$50');
      expect(amountRangeLabel(1000, 2000), '\$10 ~ \$20');
      expect(amountRangeLabel(10000, 10000), '\$100');
      expect(amountRangeLabel(100000, 250000), '\$1,000 ~ \$2,500');
    });

    test('cents back to the text of a box', () {
      expect(centsToDollarText(null), '');
      expect(centsToDollarText(0), '0');
      expect(centsToDollarText(0, emptyWhenZero: true), '');
      expect(centsToDollarText(12300), '123');
    });

    test('the date box back from an applied day', () {
      expect(DateBox.fromDate(null).isEmpty, isTrue);
      expect(DateBox.fromDate(DateTime(2026, 3, 5)), box('2026', '03', '05'));
    });
  });

  group('TransactionFilters', () {
    test('no filter means no parameters', () {
      const f = TransactionFilters();
      expect(f.toQuery(), isEmpty);
      expect(f.isActive, isFalse);
    });

    test('dates are sent as exact moments (UTC)', () {
      final f = TransactionFilters(dateStart: DateTime(2026, 3, 5), dateEnd: DateTime(2026, 3, 9, 23, 59, 59, 999));
      expect(f.toQuery(), {
        'dateRangeStart': DateTime(2026, 3, 5).toUtc().toIso8601String(),
        'dateRangeEnd': DateTime(2026, 3, 9, 23, 59, 59, 999).toUtc().toIso8601String(),
      });
      expect(f.hasDate, isTrue);
    });

    test('one side of the dates is enough', () {
      expect(TransactionFilters(dateStart: DateTime(2026, 3, 5)).toQuery().keys, ['dateRangeStart']);
      expect(TransactionFilters(dateEnd: DateTime(2026, 3, 9)).toQuery().keys, ['dateRangeEnd']);
    });

    test('amounts are sent in cents under the deposit and withdrawal names', () {
      const f = TransactionFilters(depositMin: 0, depositMax: 5000, withdrawalMin: 100);
      expect(f.toQuery(), {'depositMin': '0', 'depositMax': '5000', 'withdrawalMin': '100'});
      expect(f.hasDeposit, isTrue);
      expect(f.hasWithdrawal, isTrue);
      expect(f.hasAmount, isTrue);
    });

    test('the old amountMin and amountMax are not sent any more', () {
      const f = TransactionFilters(depositMin: 1, depositMax: 2, withdrawalMin: 3, withdrawalMax: 4);
      expect(f.toQuery().keys.where((k) => k.startsWith('amount')), isEmpty);
    });

    test('changing one kind keeps the other kind and the dates', () {
      final f = TransactionFilters(dateStart: DateTime(2026, 3, 5))
          .withAmount(MoneyKind.deposit, 100, 200)
          .withAmount(MoneyKind.withdrawal, 300, 400)
          .withAmount(MoneyKind.deposit, 500, null);
      expect(f.depositMin, 500);
      expect(f.depositMax, isNull);
      expect(f.withdrawalMin, 300);
      expect(f.withdrawalMax, 400);
      expect(f.hasDate, isTrue);
    });

    test('clearing one kind keeps the other', () {
      final f = const TransactionFilters(depositMin: 1, withdrawalMin: 2).withoutAmount(MoneyKind.deposit);
      expect(f.hasDeposit, isFalse);
      expect(f.withdrawalMin, 2);
    });

    test('clearing the date keeps the amounts', () {
      final f = TransactionFilters(dateStart: DateTime(2026, 3, 5), depositMin: 1).withoutDate();
      expect(f.hasDate, isFalse);
      expect(f.depositMin, 1);
    });

    test('minOf and maxOf pick the kind', () {
      const f = TransactionFilters(depositMin: 1, depositMax: 2, withdrawalMin: 3, withdrawalMax: 4);
      expect([f.minOf(MoneyKind.deposit), f.maxOf(MoneyKind.deposit), f.minOf(MoneyKind.withdrawal), f.maxOf(MoneyKind.withdrawal)], [1, 2, 3, 4]);
    });
  });

  test('the two kinds say what they mean', () {
    expect(MoneyKind.deposit.title, '입금 금액');
    expect(MoneyKind.deposit.meaning, '내가 받은 돈');
    expect(MoneyKind.withdrawal.title, '출금 금액');
    expect(MoneyKind.withdrawal.meaning, '내가 보낸 돈');
  });
}
