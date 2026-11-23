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
3. 이 폴더의 `.env.example`을 같은 자리의 `.env`로 복사하고 값을 채운다. **루트의 `.env`에 두지 않는다**: 그 파일은 앱 빌드에 통째로 들어가 APK에 담긴다
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

5. `pnpm e2e:generate` (Prisma client). **migrate는 쓰지 않는다**

`ANDROID_HOME`과 `JAVA_HOME`이 비어 있으면 Windows의 Android Studio 기본 자리를 쓴다(`wdio.conf.ts`).

## 실행

| 명령 (루트에서) | 하는 일 |
| --- | --- |
| `pnpm e2e` | 열 개를 차례대로 |
| `pnpm exec wdio run wdio.conf.ts --spec tests/e2e/003-transfer.spec.ts` | 하나만 |
| `pnpm e2e:types` | 타입 검사 |
| `node tests/e2e/check-header.mjs` | 모든 spec의 공통 머리말이 원본과 같은지 |

- 시험마다 **기기에 깔린 이 앱의 데이터를 비운다.** 시험용 앱이 깔린 기기에서만 돌린다.
- 시험이 만든 사용자와 거래는 개발 DB에 남는다(지우는 API가 없다). 계좌는 끝날 때 지운다.
- 내 PC가 아닌 서버는 `E2E_ALLOW_REMOTE=1`이 있을 때만 쓴다. DB는 내 PC의 것만 본다.
- 실패하면 화면 사진과 화면 구조를 `logs/`에 남긴다(커밋하지 않음).

## 버전의 짝

설정(`wdio.conf.ts`)과 설치는 저장소 루트에 있다. Wdio 10.2는 Appium 3을 받는다(4는 아니다). 루트 `pnpm-workspace.yaml`의 `nodeLinker: hoisted`는 필요하다: 기본 설치는 경로가 너무 길어 `adb`가 Appium의 도우미 앱을 열지 못한다.

## 아직 없는 것

번호를 받는 정식 실행과 결과 기록, 중계기(알림 99개, 통신 붙잡기), 실제 폰과 release 앱의 확인.
