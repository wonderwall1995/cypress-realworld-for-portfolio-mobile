import 'package:intl/intl.dart';

import 'transaction_filters.dart' show maxFilterDollars;

/// The largest amount in whole dollars that the app lets the user type: the same
/// as the server (`MAX_AMOUNT_DOLLARS`). The server keeps cents in a 32-bit
/// number, so a bigger amount would fail there.
const maxDollars = maxFilterDollars;

/// `21,474,836`, for the messages.
String get _maxDollarsText => NumberFormat.decimalPattern('en_US').format(maxDollars);

/// The check for a text field that takes whole dollars (new transaction,
/// deposit, withdraw). Returns a Korean message, or null when the text is fine.
String? validateDollars(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '금액을 입력하세요.';
  // Digits only, with an optional minus sign. (`int.tryParse` alone would also
  // accept "0x10" as 16 and "+5" as 5.)
  if (!RegExp(r'^-?[0-9]+$').hasMatch(text)) {
    return '금액은 숫자로 입력하세요. (달러 단위, 소수점 없음)';
  }
  final dollars = int.tryParse(text);
  // Only digits, but too long for a number: far too big (or far too small).
  if (dollars == null) {
    return text.startsWith('-') ? '금액은 1달러 이상이어야 합니다.' : '금액은 $_maxDollarsText달러 이하여야 합니다.';
  }
  if (dollars < 1) return '금액은 1달러 이상이어야 합니다.';
  if (dollars > maxDollars) return '금액은 $_maxDollarsText달러 이하여야 합니다.';
  return null;
}
