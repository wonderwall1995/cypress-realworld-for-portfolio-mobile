/// The phone number rule of the web settings form (`phoneRegExp` in
/// `src/components/UserSettingsForm.tsx` of the web repo), copied as it is.
///
/// It accepts digits with spaces or hyphens, for example `010-1234-5678`. It
/// does NOT accept a country code or brackets, for example `+82 10 1234 5678`
/// or `(02) 1234-5678`. The app follows the web on purpose.
final RegExp webPhoneNumberPattern = RegExp(r'^((\\+[1-9]{1,4}[ \\-]*)|(\\([0-9]{2,3}\\)[ \\-]*)|([0-9]{2,4})[ \\-]*)*?[0-9]{3,4}?[ \\-]*[0-9]{3,4}?$');

/// Returns a Korean message, or null when the number is fine.
String? validatePhoneNumber(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '전화번호를 입력하세요.';
  if (!webPhoneNumberPattern.hasMatch(text)) return '전화번호가 올바르지 않습니다.';
  return null;
}
