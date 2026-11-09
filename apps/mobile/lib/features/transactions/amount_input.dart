/// The largest amount in whole dollars that the app lets the user type.
/// The server keeps cents in a 32-bit number, so a much bigger amount would
/// fail there.
const maxDollars = 9999999;

/// The check for a text field that takes whole dollars (new transaction,
/// deposit, withdraw). Returns a Korean message, or null when the text is fine.
String? validateDollars(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '금액을 입력하세요.';
  final dollars = int.tryParse(text);
  if (dollars == null) return '금액은 숫자로 입력하세요. (달러 단위, 소수점 없음)';
  if (dollars < 1) return '금액은 1달러 이상이어야 합니다.';
  if (dollars > maxDollars) return '금액은 $maxDollars달러 이하여야 합니다.';
  return null;
}
