import 'api_client.dart';

/// The sentence a user reads when the server refuses (same sentences as the web).
///
/// The server's English message is never shown as it is. A message that is not in
/// the table gets [base] with the server's reason in brackets.
String serverRefusalText(ApiException e, {required String base}) {
  if (e.isConnection) return connectionFailedText;
  final message = e.message;
  for (final entry in _table) {
    if (message.contains(entry.key)) return entry.value;
  }
  return message.isEmpty ? base : '$base ($message)';
}

/// No answer from the server at all.
const connectionFailedText = '서버에서 처리하지 못했습니다. 잠시 뒤 다시 시도하세요';

/// A deposit has its own sentence for the "too large" refusal.
String depositRefusalText(ApiException e) {
  if (!e.isConnection && e.message.contains('balance would be too large')) {
    return '계좌 잔액 한도를 넘어서 입금할 수 없습니다';
  }
  return serverRefusalText(e, base: '입금하지 못했습니다');
}

// Order matters: the first phrase found wins.
const _table = <MapEntry<String, String>>[
  MapEntry('not enough balance', '선택한 계좌의 잔액이 부족합니다'),
  MapEntry('receiving bank account balance would be too large', '받는 계좌의 잔액 한도를 넘어서 이체할 수 없습니다'),
  MapEntry('balance would be too large', '받는 계좌의 잔액 한도를 넘어서 이체할 수 없습니다'),
  MapEntry('password is not correct', '비밀번호가 맞지 않습니다'),
  MapEntry('cannot be deleted', '잔액이 있는 계좌는 삭제할 수 없습니다'),
  MapEntry('accountNumber must be', '계좌 번호는 숫자 9~12자리여야 합니다'),
  MapEntry('bankName is required', '은행 이름을 입력하세요'),
  MapEntry('bank account not found', '은행 계좌를 찾을 수 없습니다'),
  MapEntry("not my bank account", '선택한 계좌를 사용할 수 없습니다'),
  MapEntry("not the receiver's bank account", '선택한 계좌를 사용할 수 없습니다'),
  MapEntry("not your bank account", '선택한 계좌를 사용할 수 없습니다'),
  MapEntry('was deleted', '삭제된 계좌입니다'),
  MapEntry('two different bank accounts', '서로 다른 계좌를 선택해 주세요'),
  MapEntry('amount must be', '금액이 올바르지 않습니다'),
  MapEntry("choose my bank account", '은행 계좌를 선택해 주세요'),
  MapEntry("choose the receiver's bank account", '은행 계좌를 선택해 주세요'),
];
