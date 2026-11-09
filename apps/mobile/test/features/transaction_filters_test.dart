import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final year = DateTime.now().year;

  group('toQuery', () {
    test('no filter means no parameters', () {
      expect(const TransactionFilters().toQuery(), isEmpty);
      expect(const TransactionFilters().isActive, isFalse);
    });

    test('dates are the first and last moment of the days in the phone time zone', () {
      final q = TransactionFilters(
        dateStart: DateTime(year, 3, 5, 13, 40), // the time of day is ignored
        dateEnd: DateTime(year, 3, 9),
      ).toQuery();

      expect(q['dateRangeStart'], DateTime(year, 3, 5).toUtc().toIso8601String());
      expect(q['dateRangeEnd'], DateTime(year, 3, 9, 23, 59, 59, 999).toUtc().toIso8601String());
      expect(q.containsKey('amountMin'), isFalse);
    });

    test('amounts are in cents: one step is \$10', () {
      final q = const TransactionFilters(amountMin: 2, amountMax: 5).toQuery();
      expect(q, {'amountMin': '2000', 'amountMax': '5000'});
    });

    test('the whole slider is 0 to 100000 cents (\$0 to \$1,000)', () {
      final q = const TransactionFilters(amountMin: 0, amountMax: amountSliderMax).toQuery();
      expect(q, {'amountMin': '0', 'amountMax': '100000'});
    });

    test('date and amount together', () {
      final q = TransactionFilters(
        dateStart: DateTime(year, 1, 1),
        dateEnd: DateTime(year, 1, 2),
        amountMin: 1,
        amountMax: 3,
      ).toQuery();
      expect(q.keys, containsAll(['dateRangeStart', 'dateRangeEnd', 'amountMin', 'amountMax']));
    });
  });

  group('changing one filter keeps the other', () {
    final both = TransactionFilters(
      dateStart: DateTime(year, 1, 1),
      dateEnd: DateTime(year, 1, 2),
      amountMin: 1,
      amountMax: 3,
    );

    test('clear the date', () {
      final f = both.withoutDate();
      expect(f.hasDate, isFalse);
      expect(f.hasAmount, isTrue);
    });

    test('clear the amount', () {
      final f = both.withoutAmount();
      expect(f.hasAmount, isFalse);
      expect(f.hasDate, isTrue);
    });

    test('set a new amount', () {
      final f = both.withAmount(4, 6);
      expect((f.amountMin, f.amountMax), (4, 6));
      expect(f.hasDate, isTrue);
    });
  });

  group('labels', () {
    test('nothing chosen', () {
      expect(const TransactionFilters().dateLabel, '날짜');
      expect(const TransactionFilters().amountLabel, '금액');
    });

    test('a date range in this year', () {
      final f = TransactionFilters(dateStart: DateTime(year, 3, 5), dateEnd: DateTime(year, 3, 9));
      expect(f.dateLabel, '3/5 - 3/9');
    });

    test('one day shows once', () {
      final f = TransactionFilters(dateStart: DateTime(year, 3, 5), dateEnd: DateTime(year, 3, 5));
      expect(f.dateLabel, '3/5');
    });

    test('another year shows the year', () {
      final f = TransactionFilters(dateStart: DateTime(2024, 12, 30), dateEnd: DateTime(2025, 1, 2));
      expect(f.dateLabel, '24/12/30 - 25/1/2');
    });

    test('amount range', () {
      expect(amountRangeText(0, 100), '\$0 - \$1,000');
      expect(amountRangeText(2, 5), '\$20 - \$50');
      expect(const TransactionFilters(amountMin: 2, amountMax: 5).amountLabel, '\$20 - \$50');
    });
  });
}
