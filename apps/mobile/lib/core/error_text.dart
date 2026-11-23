import 'api_client.dart';

/// The sentence a user reads when a request that changes something fails (same
/// sentences as the web).
///
/// A reason the server gives (4xx) but that is not in the table is added to [base]
/// in brackets, like the web. Anything else the server sends (5xx, an HTML page)
/// is never shown.
String serverRefusalText(ApiException e, {required String base}) {
  if (e.failure == ApiFailure.notSent) return connectionFailedText;
  if (e.resultUnknown) return resultUnknownText;
  final reason = e.serverMessage ?? '';
  for (final entry in _table) {
    if (reason.contains(entry.key)) return entry.value;
  }
  for (final error in e.fieldErrors) {
    final text = _fields[error.field];
    if (text != null) return text;
  }
  if (e.statusCode == 429) return tooManyRequestsText;
  return reason.isEmpty || e.fieldErrors.isNotEmpty ? '$base.' : '$base ($reason)';
}

/// The request did not reach the server, so nothing was done.
const connectionFailedText = '서버에 연결할 수 없어 처리하지 못했습니다. 잠시 뒤 다시 시도하세요';

/// The request left but the answer did not come (or cannot be read). The app must
/// not say that it failed, and must not send it again by itself.
const resultUnknownText = '응답을 받지 못해 처리 결과를 확인할 수 없습니다.';

/// 429, for example from the proxy in front of the server (sign-in and sign-up).
const tooManyRequestsText = '요청이 많습니다. 잠시 뒤 다시 시도하세요';

/// 409 at sign-up (the same sentence as the web).
const usernameTakenText = '이미 사용 중인 사용자 ID입니다';

/// Shown on the sign-in screen after the server ended the sign-in.
const sessionExpiredText = '로그인이 만료되었습니다. 다시 로그인해 주세요.';

/// A deposit has its own sentence for the "too large" refusal.
String depositRefusalText(ApiException e) {
  if (!e.resultUnknown && (e.serverMessage ?? '').contains('balance would be too large')) {
    return '계좌 잔액 한도를 넘어서 입금할 수 없습니다';
  }
  return serverRefusalText(e, base: '입금하지 못했습니다');
}

/// The password is wrong (403). Another 403 means the account may not be used.
bool isWrongPassword(ApiException e) =>
    e.statusCode == 403 && (e.serverMessage ?? '').contains('password is not correct');

// Order matters: the first phrase found wins.
const _table = <MapEntry<String, String>>[
  MapEntry('not enough balance', '선택한 계좌의 잔액이 부족합니다'),
  MapEntry('receiving bank account balance would be too large', '받는 계좌의 잔액 한도를 넘어서 이체할 수 없습니다'),
  MapEntry('balance would be too large', '받는 계좌의 잔액 한도를 넘어서 이체할 수 없습니다'),
  MapEntry('password is not correct', '비밀번호가 맞지 않습니다'),
  MapEntry('cannot be deleted', '잔액이 있는 계좌는 삭제할 수 없습니다'),
  MapEntry('accountNumber must be', '계좌 번호는 숫자 9~12자리여야 합니다'),
  MapEntry('bankName is required', '은행 이름을 입력하세요'),
  MapEntry('at most 60 bank accounts', '은행 계좌는 최대 60개까지 만들 수 있습니다'),
  MapEntry('bank account not found', '은행 계좌를 찾을 수 없습니다'),
  MapEntry('not my bank account', '선택한 계좌를 사용할 수 없습니다'),
  MapEntry("not the receiver's bank account", '선택한 계좌를 사용할 수 없습니다'),
  MapEntry('not your bank account', '선택한 계좌를 사용할 수 없습니다'),
  MapEntry('was deleted', '삭제된 계좌입니다'),
  MapEntry('two different bank accounts', '서로 다른 계좌를 선택해 주세요'),
  MapEntry('amount must be', '금액이 올바르지 않습니다'),
  MapEntry('choose my bank account', '은행 계좌를 선택해 주세요'),
  MapEntry("choose the receiver's bank account", '은행 계좌를 선택해 주세요'),
  MapEntry('already like this transaction', '이미 좋아요를 눌렀습니다'),
  MapEntry('transaction not found', '거래를 찾을 수 없거나 볼 수 없습니다'),
  MapEntry('only edit your own account', '내 정보만 바꿀 수 있습니다'),
];

/// The field a 422 names.
const _fields = <String, String>{
  'amount': '금액이 올바르지 않습니다',
  'description': '메모를 입력하세요',
  'content': '댓글을 입력하세요',
  'bankName': '은행 이름을 입력하세요',
  'accountNumber': '계좌 번호는 숫자 9~12자리여야 합니다',
  'myAccountId': '내 은행 계좌를 선택해 주세요',
  'otherAccountId': '받는 계좌를 선택해 주세요',
  'receiverId': '받는 사람을 다시 선택해 주세요',
  'bankAccountId': '은행 계좌를 선택해 주세요',
  'firstName': '이름을 입력하세요',
  'lastName': '성을 입력하세요',
  'username': '사용자 ID를 확인해 주세요',
  'password': '비밀번호를 확인해 주세요',
  'email': '올바른 이메일 주소를 입력하세요',
  'phoneNumber': '전화번호가 올바르지 않습니다. (예: 010-1234-5678)',
  'defaultPrivacyLevel': '공개 범위를 다시 선택해 주세요',
  'privacyLevel': '공개 범위를 다시 선택해 주세요',
};
