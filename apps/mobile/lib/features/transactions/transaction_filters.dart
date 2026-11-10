import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';

/// The largest amount in the filters, in whole dollars. The server keeps cents
/// in a 32-bit number, so this is the largest value whose cents still fit
/// (the same number as the web: `MAX_AMOUNT_DOLLARS`).
const maxFilterDollars = 21474836;

// ---------------------------------------------------------------- the date range

/// One date box = three text fields: year, month, day.
class DateBox {
  const DateBox({this.year = '', this.month = '', this.day = ''});

  final String year;
  final String month;
  final String day;

  bool get isEmpty => year.isEmpty && month.isEmpty && day.isEmpty;

  DateBox copyWith({String? year, String? month, String? day}) =>
      DateBox(year: year ?? this.year, month: month ?? this.month, day: day ?? this.day);

  /// An applied day back to the three fields: `2026`, `03`, `05`.
  factory DateBox.fromDate(DateTime? date) => date == null
      ? const DateBox()
      : DateBox(
          year: '${date.year}',
          month: date.month.toString().padLeft(2, '0'),
          day: date.day.toString().padLeft(2, '0'),
        );

  @override
  bool operator ==(Object other) =>
      other is DateBox && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

enum DateRangeError {
  /// Some of year / month / day are filled and some are not.
  incomplete,

  /// The year is not 4 digits, or the month or day is not 1 or 2 digits.
  format,

  /// A day that does not exist, for example 2026/02/30.
  invalidDate,

  /// The start day is after the end day.
  order,
}

enum DateBoxName { start, end }

/// What two date boxes mean.
class DateRangeResult {
  const DateRangeResult.empty()
      : ok = true,
        empty = true,
        start = null,
        end = null,
        error = null,
        boxes = const [];

  const DateRangeResult.range({this.start, this.end})
      : ok = true,
        empty = false,
        error = null,
        boxes = const [];

  const DateRangeResult.failed(DateRangeError this.error, this.boxes)
      : ok = false,
        empty = false,
        start = null,
        end = null;

  final bool ok;

  /// Both boxes are empty: there is no filter.
  final bool empty;

  /// The first moment of the start day, and the last moment of the end day, on
  /// the phone's calendar. One of them may be missing.
  final DateTime? start;
  final DateTime? end;

  final DateRangeError? error;

  /// Which box(es) to mark when [ok] is false.
  final List<DateBoxName> boxes;
}

/// `null` for an empty box, a date for a good box, or the error of the box.
(DateTime?, DateRangeError?) _parseDateBox(DateBox box) {
  final y = box.year.trim();
  final m = box.month.trim();
  final d = box.day.trim();
  if (y.isEmpty && m.isEmpty && d.isEmpty) return (null, null);
  if (y.isEmpty || m.isEmpty || d.isEmpty) return (null, DateRangeError.incomplete);
  if (!RegExp(r'^[0-9]{4}$').hasMatch(y) ||
      !RegExp(r'^[0-9]{1,2}$').hasMatch(m) ||
      !RegExp(r'^[0-9]{1,2}$').hasMatch(d)) {
    return (null, DateRangeError.format);
  }
  final year = int.parse(y);
  final month = int.parse(m);
  final day = int.parse(d);
  final date = DateTime(year, month, day);
  // DateTime rolls 02/30 over to 03/02, so a real date must come back unchanged.
  if (date.year != year || date.month != month || date.day != day) {
    return (null, DateRangeError.invalidDate);
  }
  return (date, null);
}

/// Start box + end box -> the date range of the filter (the same rules as the web).
///
/// The start counts from 00:00:00.000 of its day, the end until 23:59:59.999 of
/// its day, on the phone's calendar. One side may stay empty: only a start
/// means "from that day on", only an end means "up to that day". Both empty
/// means no filter.
///
/// Edge cases: a start day after the end day is refused ([DateRangeError.order]).
/// The same day in both boxes is fine and means exactly that one day.
DateRangeResult buildDateRange(DateBox startBox, DateBox endBox) {
  final (startDay, startError) = _parseDateBox(startBox);
  final (endDay, endError) = _parseDateBox(endBox);

  final errors = <(DateBoxName, DateRangeError)>[
    if (startError != null) (DateBoxName.start, startError),
    if (endError != null) (DateBoxName.end, endError),
  ];
  if (errors.isNotEmpty) {
    return DateRangeResult.failed(errors.first.$2, [for (final e in errors) e.$1]);
  }
  if (startDay == null && endDay == null) return const DateRangeResult.empty();

  final from = startDay;
  final to = endDay == null
      ? null
      : DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59, 999);

  if (from != null && to != null && from.isAfter(to)) {
    return const DateRangeResult.failed(
      DateRangeError.order,
      [DateBoxName.start, DateBoxName.end],
    );
  }
  return DateRangeResult.range(start: from, end: to);
}

/// What the screen says about a date range error.
String dateRangeErrorText(DateRangeError error, List<DateBoxName> boxes) {
  final who = boxes.length == 2
      ? '시작일과 종료일'
      : boxes.first == DateBoxName.start
          ? '시작일'
          : '종료일';
  switch (error) {
    case DateRangeError.incomplete:
      return '$who의 연·월·일을 모두 입력하세요';
    case DateRangeError.format:
      return '$who: 연도는 4자리, 월·일은 1~2자리 숫자로 입력하세요';
    case DateRangeError.invalidDate:
      return '$who: 존재하지 않는 날짜입니다';
    case DateRangeError.order:
      return '시작일이 종료일보다 늦을 수 없습니다';
  }
}

// ---------------------------------------------------------------- deposit / withdrawal amounts

enum DollarRangeError {
  /// Not whole dollars (digits only).
  format,

  /// Above [maxFilterDollars].
  tooLarge,

  /// The minimum is above the maximum.
  order,
}

class DollarRangeResult {
  const DollarRangeResult.empty()
      : ok = true,
        empty = true,
        minCents = null,
        maxCents = null,
        error = null;

  const DollarRangeResult.range(int this.minCents, this.maxCents)
      : ok = true,
        empty = false,
        error = null;

  const DollarRangeResult.failed(DollarRangeError this.error)
      : ok = false,
        empty = false,
        minCents = null,
        maxCents = null;

  final bool ok;

  /// Both boxes are empty: there is no filter.
  final bool empty;
  final int? minCents;
  final int? maxCents;
  final DollarRangeError? error;
}

/// Two boxes of whole dollars (the same rules as the web). An empty minimum
/// means 0, an empty maximum means "no upper limit".
///
/// Edge cases: a minimum above the maximum (1000 ~ 100) is refused. The same
/// number twice (100 ~ 100) is fine and means exactly that amount.
DollarRangeResult parseDollarRange(String minText, String maxText) {
  final lo = minText.trim().replaceAll(',', '');
  final hi = maxText.trim().replaceAll(',', '');
  if (lo.isEmpty && hi.isEmpty) return const DollarRangeResult.empty();

  final digits = RegExp(r'^[0-9]+$');
  for (final text in [lo, hi]) {
    if (text.isNotEmpty && !digits.hasMatch(text)) {
      return const DollarRangeResult.failed(DollarRangeError.format);
    }
  }
  // More than 12 digits is far above the limit (and could overflow the parser).
  if (lo.length > 12 || hi.length > 12) {
    return const DollarRangeResult.failed(DollarRangeError.tooLarge);
  }
  final min = lo.isEmpty ? 0 : int.parse(lo);
  final max = hi.isEmpty ? null : int.parse(hi);

  if (min > maxFilterDollars || (max != null && max > maxFilterDollars)) {
    return const DollarRangeResult.failed(DollarRangeError.tooLarge);
  }
  if (max != null && min > max) {
    return const DollarRangeResult.failed(DollarRangeError.order);
  }
  return DollarRangeResult.range(min * 100, max == null ? null : max * 100);
}

/// What the screen says about an amount range error.
String dollarRangeErrorText(DollarRangeError error) {
  switch (error) {
    case DollarRangeError.format:
      return '숫자(정수)만 입력하세요';
    case DollarRangeError.tooLarge:
      return '${NumberFormat.decimalPattern('en_US').format(maxFilterDollars)} 이하로 입력하세요';
    case DollarRangeError.order:
      return '최소 금액이 최대 금액보다 클 수 없습니다';
  }
}

/// Cents of an applied filter back to the text of a dollar box. An empty
/// minimum is shown as empty (it means 0).
String centsToDollarText(int? cents, {bool emptyWhenZero = false}) =>
    cents == null || (emptyWhenZero && cents == 0) ? '' : '${(cents / 100).round()}';

String _dollars(int cents) => '\$${NumberFormat.decimalPattern('en_US').format(cents ~/ 100)}';

/// What the chip says about an applied amount filter.
String amountRangeLabel(int? min, int? max) {
  if (min == null && max == null) return '전체';
  if (max == null) return '${_dollars(min ?? 0)} 이상';
  if ((min ?? 0) == max) return _dollars(max); // the same number twice: exactly this amount
  return '${_dollars(min ?? 0)} ~ ${_dollars(max)}';
}

/// The two kinds of amount filter, always seen from the signed-in user.
enum MoneyKind {
  /// Money I received.
  deposit('입금 금액', '내가 받은 돈', 'deposit'),

  /// Money I paid.
  withdrawal('출금 금액', '내가 보낸 돈', 'withdrawal');

  const MoneyKind(this.title, this.meaning, this.id);

  final String title;
  final String meaning;

  /// Used in the test ids: `transaction-list-filter-deposit-button`.
  final String id;
}

// ---------------------------------------------------------------- the filters

/// The date and amount filters of the three lists.
class TransactionFilters {
  const TransactionFilters({
    this.dateStart,
    this.dateEnd,
    this.depositMin,
    this.depositMax,
    this.withdrawalMin,
    this.withdrawalMax,
  });

  /// First moment of the first day and last moment of the last day, on the
  /// phone's calendar. One of them may be missing.
  final DateTime? dateStart;
  final DateTime? dateEnd;

  /// Deposit (money I received) and withdrawal (money I paid) amounts, in cents.
  final int? depositMin;
  final int? depositMax;
  final int? withdrawalMin;
  final int? withdrawalMax;

  bool get hasDate => dateStart != null || dateEnd != null;
  bool get hasDeposit => depositMin != null || depositMax != null;
  bool get hasWithdrawal => withdrawalMin != null || withdrawalMax != null;
  bool get hasAmount => hasDeposit || hasWithdrawal;
  bool get isActive => hasDate || hasAmount;

  /// The query parameters for the server. Dates are exact moments (UTC), amounts
  /// are cents. With both a deposit and a withdrawal filter, the server shows
  /// the transactions that match either one.
  Map<String, String> toQuery() => {
        if (dateStart != null) 'dateRangeStart': dateStart!.toUtc().toIso8601String(),
        if (dateEnd != null) 'dateRangeEnd': dateEnd!.toUtc().toIso8601String(),
        if (depositMin != null) 'depositMin': '$depositMin',
        if (depositMax != null) 'depositMax': '$depositMax',
        if (withdrawalMin != null) 'withdrawalMin': '$withdrawalMin',
        if (withdrawalMax != null) 'withdrawalMax': '$withdrawalMax',
      };

  int? minOf(MoneyKind kind) => kind == MoneyKind.deposit ? depositMin : withdrawalMin;
  int? maxOf(MoneyKind kind) => kind == MoneyKind.deposit ? depositMax : withdrawalMax;

  TransactionFilters withDate(DateTime? start, DateTime? end) => TransactionFilters(
        dateStart: start,
        dateEnd: end,
        depositMin: depositMin,
        depositMax: depositMax,
        withdrawalMin: withdrawalMin,
        withdrawalMax: withdrawalMax,
      );

  TransactionFilters withoutDate() => withDate(null, null);

  /// Changes one kind of amount filter and keeps the other kind as it is.
  TransactionFilters withAmount(MoneyKind kind, int? min, int? max) => TransactionFilters(
        dateStart: dateStart,
        dateEnd: dateEnd,
        depositMin: kind == MoneyKind.deposit ? min : depositMin,
        depositMax: kind == MoneyKind.deposit ? max : depositMax,
        withdrawalMin: kind == MoneyKind.withdrawal ? min : withdrawalMin,
        withdrawalMax: kind == MoneyKind.withdrawal ? max : withdrawalMax,
      );

  TransactionFilters withoutAmount(MoneyKind kind) => withAmount(kind, null, null);
}

/// The filters. They are the same for the three lists, and start again when
/// another user signs in.
class TransactionFiltersController extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() {
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    return const TransactionFilters();
  }

  void setDate(DateTime? start, DateTime? end) => state = state.withDate(start, end);
  void clearDate() => state = state.withoutDate();
  void setAmount(MoneyKind kind, int? min, int? max) =>
      state = state.withAmount(kind, min, max);
  void clearAmount(MoneyKind kind) => state = state.withoutAmount(kind);
  void clearAll() => state = const TransactionFilters();
}

final transactionFiltersProvider =
    NotifierProvider<TransactionFiltersController, TransactionFilters>(
  TransactionFiltersController.new,
);
