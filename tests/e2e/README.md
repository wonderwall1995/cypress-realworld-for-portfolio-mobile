# App E2E 테스트 (Wdio + Appium)

읽는 사람: 이 테스트를 돌리거나 읽는 사람. 테스트의 규칙은 모든 spec 맨 위의 공통 머리말(`testcode.template.ts`)에 있다.

| 폴더 | 내용 |
| --- | --- |
| `NNN-이름.spec.ts` | 시험. 웹의 같은 번호 시험과 짝이다 |
| `common/` | 화면 동작 |
| `common/screen/` | 화면의 바닥 도구 (찾기, 쓰기, 꺼짐 읽기, 스크롤) |
| `api/` | 준비, 서버 판정, 정리. 사람마다 따로 로그인한다 |
| `db/` | 내 PC의 DB를 **읽기만** 하는 판정 |
| `fixture/` | 무작위 값, 실행 번호의 값, 단계 기록 |

## 준비 (한 번)

1. 서버(API 7202)와 DB, 에뮬레이터를 켜고 **debug 앱**을 깐다 (`pnpm device:start`, `pnpm build`, `pnpm start`). 앱과 테스트는 같은 서버를 본다.
2. 저장소 루트에서 `pnpm install`
3. 이 폴더의 `.env.example`을 같은 자리의 `.env`로 복사하고 값을 채운다. 루트의 `.env`는 앱 빌드에 넘기는 값만 두는 곳이라 따로 둔다(앱이 쓰지 않는 값은 APK에 들어가지 않는 것을 확인했다. 그래도 나중에 앱이 같은 이름을 쓰면 들어간다)
4. DB 읽기 전용 사용자를 만든다. 비밀번호는 저장소에 두지 않는다

   ```sql
   create role e2e_reader login password '<무작위>' nosuperuser nocreatedb nocreaterole;
   alter role e2e_reader set default_transaction_read_only = on;
   grant connect on database <DB 이름> to e2e_reader;
   grant usage on schema public to e2e_reader;
   grant select ("id", "username") on public.users to e2e_reader;
   grant select ("id", "userId", "visible", "balance") on public.bank_accounts to e2e_reader;
   grant select ("id", "userId") on public.bank_transfers to e2e_reader;
   grant select ("id", "senderId", "receiverId") on public.transactions to e2e_reader;
   ```

5. `pnpm test:generate` (Prisma client). **migrate는 쓰지 않는다**

`ANDROID_HOME`과 `JAVA_HOME`이 비어 있으면 Windows의 Android Studio 기본 자리를 쓴다(`wdio.conf.ts`).

## 실행

| 명령 (루트에서) | 하는 일 |
| --- | --- |
| `pnpm test` | 준비를 점검하고 열 개를 차례대로 |
| `pnpm test --spec 003` | 이름에 003이 든 것만 |
| `pnpm test --spec 002 --spec 003` | 둘만 |
| `pnpm test:run` | **정식 실행.** 번호 서버에서 번호와 값을 받아 전부 돌리고, 끝나면 알린다 |
| `pnpm test:types` | 타입 검사 |
| `pnpm app:test` | 앱 안의 테스트(Dart). 기기가 필요 없다 |

- 준비가 안 됐으면 **무엇이 빠졌는지 알려 주고 시작하지 않는다** (`preflight.ts`).
- 시험마다 **기기에 깔린 이 앱의 데이터를 비운다.** 시험용 앱이 깔린 기기에서만 돌린다.
- 시험이 만든 사용자와 거래는 개발 DB에 남는다(지우는 API가 없다). 계좌는 끝날 때 지운다.
- 내 PC가 아닌 서버는 `E2E_ALLOW_REMOTE=1`이 있을 때만 쓴다. DB는 내 PC의 것만 본다.
- 실패하면 화면 사진과 화면 구조를 `logs/`에 남긴다(커밋하지 않음).

## 정식 실행

- Web이 먼저 돈 최신 번호가 있으면 그 번호에 **합류**하고, 아니면 새 번호를 연다. 받은 값에 시험의 이름표가 하나라도 없으면 block을 보내고 멈춘다.
- 번호를 열 때 **어떤 코드로 도는지**도 알린다: 시험 코드의 커밋, 커밋하지 않은 변경이 있는지, 깔린 앱의 지문. 서버가 지문마다 버전(0.100, 0.101 ...)을 매긴다.
- 앱의 지문은 `pnpm build`가 소스로 계산해 Android 버전 이름에 붙인다(`1.0.0-<지문 16자>`). 다른 방법(`pnpm app:run` 등)으로 만든 앱이면 앱 버전은 빈칸이다. API 주소 같은 `.env`의 값은 지문에 들어가지 않는다.
- 번호 서버에 남는 기기 이름은 `rwa-mobile`이다. 다른 이름은 `tests/e2e/.env`의 `TEST_RUN_DEVICE`에 넣는다.
- `TEST_RUN_SECRET`은 `tests/e2e/.env`에만 둔다(웹 서버의 값과 같은 값).
- 실패한 시험이 있어도 끝까지 돌았으면 finish, 중간에 멈추면 block(그 번호는 무효)이다. 시험이 끝날 때마다 그 시험과 도구의 결과를 보낸다(신호를 겸함). 끝에 모두 한 번 더 보내고, 저장되지 않은 것이 있으면 block이다. 번호를 받은 뒤에 오류가 나도 block을 보낸다.
- 시작과 끝의 규칙은 가짜 번호 서버로 확인했다. 로컬 번호 서버로 실행 번호 4, 5, 6을 끝까지 돌렸고, 5번과 6번의 결과가 저장된 것을 확인했다(2026-11-24). 6번은 번호 서버의 새 테이블(app_test_record, app_test_report)로 돌렸다. **그 뒤 로컬의 1~8번 기록은 모두 지웠고, 번호는 다시 1번부터 시작한다.** 배포 서버의 번호 기능은 닫혀 있다.

## 버전의 짝

설정(`wdio.conf.ts`)과 설치는 저장소 루트에 있다. Wdio 10.2는 Appium 3을 받는다(4는 아니다). 루트 `pnpm-workspace.yaml`의 `nodeLinker: hoisted`는 필요하다: 기본 설치는 경로가 너무 길어 `adb`가 Appium의 도우미 앱을 열지 못한다.

## 아직 없는 것

중계기(알림 99개, 통신 붙잡기), 실제 폰과 release 앱의 확인.
