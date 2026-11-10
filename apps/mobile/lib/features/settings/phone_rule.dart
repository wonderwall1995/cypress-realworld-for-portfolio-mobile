/// The phone number rule of the server (`PHONE_NUMBER_PATTERN` in the web
/// repo's shared package), the same for sign-up and for the settings screen.
///
/// Digits, spaces, hyphens and brackets, with an optional leading "+". From 7
/// to 20 characters; it starts and ends with a digit. Examples that pass:
/// `010-1234-5678`, `+82 10-1234-5678`, `(02) 123-4567`.
final RegExp serverPhoneNumberPattern = RegExp(r'^\+?\d[\d\s()-]{5,18}\d$');

/// Returns a Korean message, or null when the number is fine.
///
/// [noun] is the word the screen uses: "전화번호" in settings, "연락처" in sign-up.
String? validatePhoneNumber(String? value, {String noun = '전화번호'}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '$noun를 입력하세요.';
  if (!serverPhoneNumberPattern.hasMatch(text)) {
    return '$noun가 올바르지 않습니다. (예: 010-1234-5678)';
  }
  return null;
}
