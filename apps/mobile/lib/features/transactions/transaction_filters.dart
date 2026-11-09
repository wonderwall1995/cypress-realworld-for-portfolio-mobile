import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import 'transaction.dart';

/// The slider has 100 steps. One step is $10, so the range is $0 to $1,000
/// (same as the web).
const amountUnitDollars = 10;
const amountSliderMax = 100;

/// The date and amount filters of the three lists.
class TransactionFilters {
  const TransactionFilters({this.dateStart, this.dateEnd, this.amountMin, this.amountMax});

  /// First and last day, as dates on the phone's calendar (time of day is ignored).
  final DateTime? dateStart;
  final DateTime? dateEnd;

  /// Slider steps (each step is [amountUnitDollars] dollars).
  final int? amountMin;
  final int? amountMax;

  bool get hasDate => dateStart != null && dateEnd != null;
  bool get hasAmount => amountMin != null && amountMax != null;
  bool get isActive => hasDate || hasAmount;

  /// The query parameters for the server.
  ///
  /// Dates: from the start of the first day to the end of the last day, in the
  /// phone's time zone, sent as exact moments (UTC). Amounts: in cents.
  ///
  /// A smallest amount of 0 is sent as it is. (Checked on the real server: it
  /// filters correctly with 0 on all three lists.)
  Map<String, String> toQuery() => {
        if (hasDate)
          'dateRangeStart': DateTime(dateStart!.year, dateStart!.month, dateStart!.day)
              .toUtc()
              .toIso8601String(),
        if (hasDate)
          'dateRangeEnd':
              DateTime(dateEnd!.year, dateEnd!.month, dateEnd!.day, 23, 59, 59, 999)
                  .toUtc()
                  .toIso8601String(),
        if (hasAmount) 'amountMin': '${amountMin! * amountUnitDollars * 100}',
        if (hasAmount) 'amountMax': '${amountMax! * amountUnitDollars * 100}',
      };

  TransactionFilters withDate(DateTime start, DateTime end) => TransactionFilters(
        dateStart: start,
        dateEnd: end,
        amountMin: amountMin,
        amountMax: amountMax,
      );

  TransactionFilters withoutDate() => TransactionFilters(amountMin: amountMin, amountMax: amountMax);

  TransactionFilters withAmount(int min, int max) => TransactionFilters(
        dateStart: dateStart,
        dateEnd: dateEnd,
        amountMin: min,
        amountMax: max,
      );

  TransactionFilters withoutAmount() => TransactionFilters(dateStart: dateStart, dateEnd: dateEnd);

  /// For example `11/9 - 11/10`. One day shows as `11/9`. A date in another
  /// year shows the year, for example `25/12/30`.
  String get dateLabel {
    if (!hasDate) return '날짜';
    final now = DateTime.now();
    String day(DateTime d) =>
        d.year == now.year ? '${d.month}/${d.day}' : '${d.year % 100}/${d.month}/${d.day}';
    final same = dateStart!.year == dateEnd!.year &&
        dateStart!.month == dateEnd!.month &&
        dateStart!.day == dateEnd!.day;
    return same ? day(dateStart!) : '${day(dateStart!)} - ${day(dateEnd!)}';
  }

  /// For example `$0 - $50`.
  String get amountLabel =>
      hasAmount ? amountRangeText(amountMin!, amountMax!) : '금액';
}

/// `$0 - $50` for slider steps 0 and 5. The whole range is `$0 - $1,000`.
String amountRangeText(int min, int max) =>
    '${formatUsd(min * amountUnitDollars * 100).replaceAll('.00', '')} - '
    '${formatUsd(max * amountUnitDollars * 100).replaceAll('.00', '')}';

/// The filters. They are the same for the three lists, and start again when
/// another user signs in.
class TransactionFiltersController extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() {
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    return const TransactionFilters();
  }

  void setDate(DateTime start, DateTime end) => state = state.withDate(start, end);
  void clearDate() => state = state.withoutDate();
  void setAmount(int min, int max) => state = state.withAmount(min, max);
  void clearAmount() => state = state.withoutAmount();
  void clearAll() => state = const TransactionFilters();
}

final transactionFiltersProvider =
    NotifierProvider<TransactionFiltersController, TransactionFilters>(
  TransactionFiltersController.new,
);
