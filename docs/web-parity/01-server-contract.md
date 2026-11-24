# 모바일을 위한 서버 계약과 연동 예외처리

모바일 앱은 별도 서버를 갖지 않고 웹 저장소의 Express API를 사용한다. 우선 현재 계약을 유지하면서 앱의 오류 처리를 보완한다. 중복 요청 방지와 구조화된 오류 같은 계약 확장은 웹 담당자의 서버 작업으로 분리한다.

## 접속과 인증

`API_BASE_URL`은 `/api`를 포함한 주소다. 각 요청 경로는 아래 표와 같이 `/login` 등으로 쓴다. Android 에뮬레이터, 실기기, 배포 환경의 접속 주소는 설정으로 구분한다. 릴리스 설정은 HTTPS만 허용한다.

로그인은 세션 쿠키 방식이다. 앱의 일반 요청과 SSE는 같은 `CookieJar`를 사용한다. 앱은 `remember=true`인 만료일 있는 쿠키를 디스크에 저장하며, 세션 쿠키는 앱 재시작 뒤 유지하지 않는다. 서버는 기본 메모리 세션 저장소를 사용하므로 쿠키에 만료일이 남아 있어도 서버 재시작 뒤 재로그인이 필요할 수 있다.

현재 서버 CORS는 로컬 웹 출처를 대상으로 설정되어 있다. 네이티브 Dio 접속과 브라우저의 CORS 처리는 구분해야 한다. Flutter Web을 지원한다면 별도 검토한다. 실제 배포 프록시의 쿠키 전달과 SSE 동작도 연결 환경에서 확인해야 한다.

근거: W `apps/api/src/app.ts`, `auth.ts`, `session-secret.ts`; M `apps/mobile/lib/core/config.dart`, `api_client.dart`.

## 업무 API

아래 경로에는 모두 `/api` 접두사가 붙는다. 본문 예시는 필드와 단위를 설명하는 계약이다.

| 사용자 행동 | API와 성공 응답 | 요청과 응답에서 지킬 점 |
| --- | --- | --- |
| 로그인 | `POST /login` → 200 `{ user }` | `username`, `password`, `remember`. 실패 401을 세션 만료 안내와 구분한다. |
| 로그인 복원 | `GET /checkAuth` → 200 `{ user }`, 세션 없음 401 | 네트워크 실패와 서버가 확인한 비로그인을 분리한다. |
| 회원가입 | `POST /users` → 201 `{ user }` | 성, 이름, 사용자명, 비밀번호, 필수 전화번호. 자동 로그인하지 않는다. |
| 로그아웃 | `POST /logout` → 리다이렉트 | 앱은 리다이렉트를 따라가지 않고 로컬 쿠키를 지운다. 서버 연결 실패 시에도 로컬 로그아웃한다. |
| 내 계좌 목록 | `GET /bankAccounts` → 200 `{ results }` | `visible=true`인 계좌. 잔액은 센트다. |
| 계좌 등록 | `POST /bankAccounts` → 200 `{ account }` | `bankName`, 숫자 9~12자리 문자열 `accountNumber`. 라우팅 번호 없음. 활성 계좌 최대 60개. |
| 계좌 삭제 | `DELETE /bankAccounts/:id` → 200 `{}` | 논리 삭제. 잔액이 있으면 400, 남의 계좌나 없는 계좌는 404. |
| 이체 상대 찾기 | `GET /users` 또는 `/users/search?q=...` → 200 `{ results }` | 본인 제외. 빈 검색은 전체 목록. 이름과 전화번호 검색을 안내한다. |
| 상대 수취 계좌 | `GET /bankAccounts/of-user/:userId` → 200 `{ results }` | `id`, `bankName`, `accountNumberLast4`만 사용한다. 상대 잔액과 전체 계좌번호를 기대하지 않는다. |
| 비밀번호 확인 | `POST /users/verifyPassword` → 204 | `{ password }`. 틀리면 403. 이 응답만으로 이체 완료라고 표시하지 않는다. |
| 즉시 이체 | `POST /transactions` → 200 `{ transaction }` | `transactionType: payment`, `receiverId`, `description`, 정수 달러 `amount`, `myAccountId`, `otherAccountId`, `password`, `privacyLevel`. 실제 이체에서도 비밀번호를 다시 검사한다. |
| 가상 입금 | `POST /bankTransfers` → 201 `{ transfer }` | `bankAccountId`, 정수 달러 `amount`, `type: deposit`. 외부 입금 거래도 함께 생성된다. |
| 입출금 이력 | `GET /bankTransfers` → 200 `{ transfers }` | 금액, 전후 잔액은 센트. 서버는 withdrawal도 지원하지만 앱에 출금 화면을 새로 만들 필요는 없다. |
| 입출금 상태 기록 | `GET /bankTransfers/:id/logs` → 200 `{ logs }` | 본인 기록만 조회 가능. 상태 확인 화면이 필요할 때 쓰는 선택 기능이다. |
| 거래 목록 | `GET /transactions/public`, `GET /transactions` → 200 `{ results, pageData }` | 전체와 내 거래. `page`, `limit`, `hasNextPages`를 사용한다. 친구 API 없음. |
| 거래 상세 | `GET /transactions/:id` → 200 `{ transaction }` | 없는 거래와 접근 불가 거래 모두 404. 구별해서 개인정보를 노출하지 않는다. |
| 좋아요 | `POST /likes/:transactionId` → 200 | 같은 사용자와 거래의 중복은 409 `you already like this transaction`. 최신 상세를 다시 읽는다. |
| 댓글 | `POST /comments/:transactionId` → 200 | `{ content }`. 공백만 있는 댓글은 거절된다. |
| 미읽음 알림 | `GET /notifications` → 200 `{ results }` | 전체 알림 이력이 아닌 미읽음 목록이다. |
| 알림 읽음 | `PATCH /notifications/:id` → 204 | `{ isRead: true }`. 승인 후 목록과 배지를 바꾼다. |
| 사용자 설정 | `PATCH /users/:id` → 204 | 본인만 수정. 이메일과 전화번호 빈 문자열은 null로 저장. 변경 없음도 성공. |

근거: W `apps/api/src/*-routes.ts`, `validators.ts`, `bankaccount-db.ts`, `social-db.ts`; M `apps/mobile/lib/core/api_client.dart`.

## 금액과 공개 범위

- 송금과 입금 입력은 정수 달러다. 거래와 계좌의 응답 잔액, 거래 금액 필터는 센트다. 예를 들어 입력 7은 7달러, 응답 700은 7달러다.
- 앱의 금액 입력 상한은 21,474,836달러, 서버의 센트 저장 상한은 2,147,483,647이다. 한 번의 입력 상한을 통과해도 기존 잔액 때문에 입금이나 수취가 거절될 수 있다. 서버의 계좌 잔액과 합계 제한 처리를 최종 판단으로 쓴다.
- 거래 항목의 `myAccount.balanceAfter`는 해당 거래 직후의 잔액이다. 지금의 잔액과 구분한다. `myAccount`가 없으면 상대 계좌나 잔액을 추측해 만들지 않는다.
- 현재 생성하는 거래는 `payment`뿐이다. 요청, 수락, 거절, 친구, 라우팅 번호 기능을 복구하지 않는다.
- 앱의 설정과 새 이체는 `public` 또는 `private`를 쓴다. 예전 `contacts` 거래는 당사자 외에는 비공개처럼 처리된다. 현재 서버의 설정 검사는 두 값만 허용하지만 이체 본문의 privacyLevel 검사는 `contacts`가 남은 공유 enum을 그대로 사용한다. 서버가 새 이체의 `contacts`까지 거절한다고 가정하면 안 된다.
- 전체 목록은 **공개 거래와 내 외부 입금**을 포함한다. 내가 당사자여도 일반 비공개 이체는 전체 목록에 추가되지 않으며 내 거래에서 확인한다. 비공개 거래의 상세는 당사자가 볼 수 있다. 목록 포함 여부와 상세 접근 권한을 구분한다.
- 금액 필터는 `depositMin`, `depositMax`, `withdrawalMin`, `withdrawalMax`를 센트로 보낸다. 입금과 출금 필터를 동시에 켜면 둘 중 하나에 맞는 거래를 받는다. 날짜 조건은 함께 적용한다.
- 날짜는 단말의 선택한 날을 시작과 끝 시각으로 만든 뒤 UTC로 전송하는 앱 방식을 유지한다. 같은 날짜라도 기기의 시간대가 다르면 기간이 달라질 수 있으므로 시간대 기준을 안내한다.

근거: W `packages/shared/src/limits.ts`, `apps/api/src/access.ts`, `transaction-db.ts`, `account-money.ts`, `banktransfer-service.ts`; M `features/transactions/transaction_filters.dart`, `transaction.dart` 이하 경로는 `apps/mobile/lib/` 기준.

## 오류를 사용자 행동으로 연결

| 상황 | 현재 계약 또는 코드 차이 | 앱에 필요한 처리 |
| --- | --- | --- |
| 보호 API 401 | 공통 세션 만료 전환 없음. `refreshUser()`도 checkAuth의 null을 무시한다. | 세션 종료 상태로 전환하고 SSE와 민감한 캐시를 정리한다. 로그인 실패 401은 로그인 화면 안에서 처리한다. |
| 비밀번호 또는 계좌 권한 403 | 이체 확인 창은 잔액 문구가 없는 403을 모두 비밀번호 오류로 표시한다. | `password is not correct`일 때만 비밀번호 재입력을 요구한다. 권한 오류는 계좌 재선택으로 연결한다. |
| 거래 404 | 상세 화면은 일반 실패와 재시도만 제공한다. | “거래를 찾을 수 없거나 볼 수 없습니다”와 목록 돌아가기를 제공한다. |
| 좋아요 409 | 서버는 이미 중복을 거절하지만 앱 주석은 중복 허용이라고 설명한다. | 이미 반영된 상태로 안내하고 상세와 목록을 재조회한다. 자동 재전송하지 않는다. |
| 입력 422 | 서버는 `{ errors: [{ msg, param, ... }] }` 형태다. 앱은 첫 항목의 `message`만 찾는다. | `msg`와 `param`을 읽어 필드 옆에 표시한다. 알 수 없는 구조도 안전한 공통 안내로 처리한다. |
| 계좌 제한 400 | `a user can have at most 60 bank accounts`가 번역 표에 없다. | 활성 계좌 수와 등록 한도를 안내하고 등록 폼 값을 유지한다. |
| 연결 또는 수신 시간 초과 | 앱은 “서버에서 처리하지 못했습니다”라고 단정한다. | 조회 실패와 쓰기 결과 불명을 구분한다. 송신 후 실패는 서버 처리 여부를 단정하지 않는다. |
| 5xx 또는 HTML 응답 | 모든 오류가 HttpError의 JSON 형태인 것은 아니다. | 내부 오류 본문을 그대로 노출하지 않고 안전한 안내를 표시한다. 쓰기는 결과 불명 정책을 적용한다. |
| 응답 형식 불일치 | 다수 파서가 강제 형변환하며 호출부는 ApiException만 잡는다. | TypeError와 FormatException 등이 화면을 중단하지 않도록 계약 오류로 바꾸고 재조회 경로를 제공한다. |

근거: W `helpers.ts`, `app.ts`, `account-money.ts`, `social-db.ts`; M `core/api_client.dart`, `core/session.dart`, `core/error_text.dart`, `features/transactions/create/password_confirm_dialog.dart`.

## 서버 담당자에게 전달할 보완 제안

### P0 중복 처리 방지

현재 입금과 이체 API에는 클라이언트 요청 식별자에 따른 중복 방지가 없다. 앱의 `_busy`는 같은 화면의 연속 클릭만 막는다. 서버가 처리한 뒤 응답이 사라지면 다시 누른 요청이 별도 거래가 될 수 있다.

제안은 사용자와 작업 식별자를 묶어 한 번만 처리하고, 같은 요청 재전송에는 처음 결과를 돌려주는 계약이다. 같은 식별자로 다른 금액이나 계좌를 보내면 거절해야 한다. 결과 조회 방법, 보관 기간, 처리 중 응답, 거래와 식별자의 원자적 저장을 함께 정한다. 필드명과 엔드포인트는 아직 확정되지 않았다.

서버 보완 전에는 결과 불명 안내와 내 거래·입출금 이력·잔액 조회를 먼저 제공한다. 금액과 시각만 비교해서 “이 요청이 성공했다”고 확정하면 안 된다. 쓰기 요청을 자동 재시도하지 않는다.

### P1 오류 코드와 상태 조회

영문 문장 부분 일치 대신 안정된 `code`, 사용자에게 보여 줄 메시지, 필요한 경우 필드 오류 목록을 내려주는 계약을 제안한다. 적용 전에는 현재 `{ error }`와 `{ errors }`를 함께 읽는다. 계좌 생성과 댓글의 응답 손실도 중복 가능성이 있으므로 금액 처리 다음에 같은 정책을 검토한다.

새 거래의 공개 범위 검사를 설정과 같은 `public/private`로 맞출지도 서버 요청에 포함한다. 현재 이체 validator는 `DefaultPrivacyLevelValues`를 사용해 `contacts`도 통과시킨다. 이는 “친구 개념 제거”라는 기존 문서와 구현의 차이다. 앱은 제거된 친구 UI를 복원하지 않고 두 값만 전송한다.

### P1 서버 동시 처리 확인

계좌 60개 제한은 개수 조회 후 생성, 계좌 삭제는 잔액 조회 후 숨김 처리다. 입금과 이체의 사용 가능 확인과 잔액 잠금도 별도 단계다. 생성 동시 실행, 삭제와 입금·이체 동시 실행에서 제한과 visible 규칙이 끝까지 유지되는지 서버에서 확인할 필요가 있다. 이번 비교에서는 동시 실행을 재현하지 않았으므로 확정 버그로 취급하지 않는다.

### 운영 환경 확인

SSE는 사용자당 최대 3개 연결, 25초 heartbeat, 재연결 간격 안내 5초이며 이벤트 재전송은 없다. 서버 프로세스 메모리에 연결이 있으므로 다중 서버 배포 시 전달 구조를 검토한다. 세션 저장소, 프록시 버퍼링, 서버 재시작 뒤 앱의 재로그인을 함께 확인한다. 개발용 데이터 초기화와 테스트 관리 API를 앱 일반 사용자 기능으로 연결하지 않는다.

근거: W `notification-stream.ts`, `app.ts`, `bankaccount-db.ts`, `account-money.ts`, `banktransfer-service.ts`, `transaction-db.ts`.
