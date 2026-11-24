# GitHub Release로 APK 배포하기: 시점과 방법

- 작성: 2026-11-24. 처음에는 계획 문서였다. **지금 쓰는 방법은 바로 아래 0절(내 PC에서 명령 하나)이다.** 나머지는 그때의 계획이고, GitHub Actions는 쓰지 않는다.
- 읽는 사람: 이 저장소의 주인(배포를 정하고 실행하는 사람).
- 공개 저장소다. 이 문서에 키, 비밀번호, 관리용 주소를 쓰지 않는다.
- 표시: **확인함**(이 저장소나 공식 문서를 읽음), **미확인**(해 보지 않음)

## 0. 지금 쓰는 방법: 내 PC에서 명령 하나

| 명령 (루트에서) | 하는 일 |
| --- | --- |
| `pnpm release:build` | 만들고 확인만 한다. 아무것도 올리지 않는다 |
| `pnpm release:draft` | 만들고 확인한 뒤 GitHub에 **초안(시험판)** 으로 올린다 |
| `pnpm release:build --try` | `main`이 아닌 코드로 만들어 본다. 올릴 수 없다 |

**공개(Publish)는 자동으로 하지 않는다.** 폰에서 확인한 뒤 GitHub 화면에서 사람이 누른다.

### 처음 한 번만

1. `winget install GitHub.cli`로 `gh`를 설치하고, CMD 창을 새로 열어 `gh auth login`을 한다(GitHub.com, HTTPS, 브라우저로 로그인).
2. 저장소 맨 위에 `.env.release`를 만들고 `API_BASE_URL=https://.../api`를 적는다(커밋되지 않는다).
3. 서명 키와 `apps/mobile/android/key.properties`를 만든다(5절).

### 릴리스할 때마다

1. `apps/mobile/VERSION`을 올리고 커밋해 `main`에 병합한다. 안쪽 빌드 번호는 여기서 계산된다.
2. `main`에서 `pnpm release:draft`를 돌린다.
3. 초안에서 APK를 받아 폰에서 확인하고, 글을 다듬고, **Publish release**를 누른다.

### 이럴 때는 멈추고 올리지 않는다

- `main`이 아니거나, GitHub의 `main`과 다르거나, 커밋하지 않은 변경이 있다
- 그 버전의 태그나 초안이 이미 있다
- 서명 키나 `.env.release`가 없거나, 배포 서버가 답하지 않는다
- `flutter analyze`나 `flutter test`가 실패한다
- 만든 APK가 내 키로 서명되지 않았거나, 버전, 기기 종류, 서버 주소가 다르거나, 비밀번호나 비밀 파일이 들어 있다
- 만드는 동안 소스가 바뀐다

릴리스 글의 틀은 `release-notes.template.md`다. 서명 키는 이 PC를 떠나지 않는다. 사본 저장소와 가짜 `gh`로 26가지 상황을 확인했다. **진짜 GitHub에 올리는 것은 아직 해 보지 않았다.**

## 1. 한 줄 답

**기술로는 서명 키를 만들면 할 수 있다. 남에게 주는 것은 2단계가 끝난 뒤를 권한다.**

Android의 개발자 확인 제도는 2027년에 전 세계로 넓어진다. 한국에서 쓸 포트폴리오라면 **그 전에 제한 배포 계정이나 개발자 확인을 준비**하는 것이 좋다(6절).

## 2. 언제 가능한가

| 단계 | 조건 | 지금 | 할 수 있는 것 |
| --- | --- | --- | --- |
| 0 | 코드가 준비됨 | **됨.** release 빌드가 되고 https 주소만 받는다(확인함) | 내 PC에서 APK 만들기 |
| 1 | 서명 키, push와 병합, 배포 서버의 로그인 확인 | 안 됨 | **시험판(pre-release)을 나만 설치** |
| 2 | 로그인 유지, 실제 폰 확인 | 안 됨 | **면접관에게 링크 주기** |
| 3 | Android 개발자 확인 대비 | 안 됨 | 2027년 뒤에도 설치가 쉬움 |

### 1단계에 필요한 것

| 번호 | 할 일 | 누가 |
| --- | --- | --- |
| 1 | release 서명 키(keystore)를 만들고 **두 곳에 백업** (5절) | 나 |
| 2 | `feat/web-parity`(main보다 커밋 17개 앞섬)를 push하고 main에 병합 | 나 |
| 3 | 배포 서버 주소로 만든 release 앱이 로그인되는지 확인 | 나 |
| 4 | 릴리스 작업 파일(4절)을 저장소에 넣기 | 정하면 LLM |
| 5 | GitHub에 환경(environment)과 비밀 값 넣기 (4절) | 나 |

### 2단계에 필요한 것

| 번호 | 할 일 | 왜 배포 전인가 |
| --- | --- | --- |
| 1 | 서버를 다시 켜도 로그인 유지 | 면접 중에 로그아웃되지 않게 |
| 2 | 가입과 로그인의 횟수 제한이 배포 서버에 적용됐는지 확인 | 공개 주소를 앱에 담아 나눠 준다 |
| 3 | 실제 폰에서 설치, 로그인, 이체, 실시간 알림 확인 | 에뮬레이터로만 확인했다 |
| 4 | README에 설치 방법과 "지어낸 정보만 넣어 달라"는 안내 | 앱 안에는 이미 있다 |

1은 서버 쪽에 이미 요청한 일이다. 데모 서버의 DB 탭이 모든 칸을 보여 주는 것은 의도다(사용자 결정). 앱이 기다릴 것은 없다.

## 3. 어떤 방식으로

| 방식 | 하는 일 | 좋은 점 | 나쁜 점 |
| --- | --- | --- | --- |
| **가 (추천)** | **태그를 push하면** GitHub Actions가 빌드, 서명, 초안 릴리스까지. **내가 보고 공개** | 어느 커밋으로 만들었는지 분명하다. 내 PC에 기대지 않는다 | 서명 키를 GitHub 비밀 값으로 올려야 한다 |
| 나 | 내 PC에서 빌드하고 `gh release create`로 올림 | 키가 내 PC 밖으로 나가지 않는다. 바로 할 수 있다 | 사람이 하는 일이 많고, 무엇으로 만들었는지 증명하기 어렵다 |
| 다 | push할 때마다 자동 빌드 | 항상 최신 | 앞서 자동 확인(GitHub Actions)을 하지 않기로 했다. 필요 없다 |

**순서:** 처음 한 번은 **나**로 시험판을 만들어 설치까지 확인하고, 그다음 **가**로 옮기는 것을 권한다. 자동화가 실패했을 때 키의 문제인지 빌드의 문제인지 가르기 쉽다.

"GitHub Actions 자동 확인은 하지 않는다"는 결정과 부딪히지 않는다. 이것은 push마다 도는 검사가 아니라 **릴리스할 때만** 도는 작업이다. 릴리스 작업 안에서 `flutter analyze`와 `flutter test`를 돌릴지는 정해야 한다(권함: 돌린다).

마켓 배포가 아니다. 앱 이름에 "Cypress"가 있어 마켓에는 내지 않기로 한 결정은 그대로다. GitHub Release도 **누구나 받을 수 있는 공개**라는 점은 같으므로, 릴리스 글에 비공식 데모이고 제휴가 아니라는 문장과 MIT 라이선스를 함께 적는다. 법률 자문은 아니다.

## 4. 방법 (가안)

### 4-1. GitHub에 넣을 것

저장소 Settings에서 `release`라는 **environment**를 만들고 나를 필수 승인자로 둔다. 승인하기 전에는 작업이 비밀 값을 읽지 못한다. 공개 저장소는 무료 요금제에서도 쓸 수 있다(GitHub 문서). 승인자 자신을 막는 설정은 켜지 않는다(혼자 쓰는 저장소다).

| 이름 | 어디에 | 내용 |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64` | environment 비밀 값 | 키 파일을 base64로 바꾼 글자 |
| `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD` | environment 비밀 값 | 비밀번호 |
| `ANDROID_KEY_ALIAS` | environment 비밀 값 | 키 이름 |
| `API_BASE_URL` | environment **변수** | `https://.../api`. 비밀이 아니다. APK를 풀면 누구나 볼 수 있다 |

비밀 값은 GitHub 화면에서 직접 넣는다. 채팅이나 파일로 LLM에게 주지 않는다.

### 4-2. 작업 파일 초안

`.github/workflows/release-apk.yml`. **한 번도 돌려 보지 않았다.** 넣기 전에 각 action의 최신 버전을 확인하고, 커밋 해시로 고정하는 것을 권한다.

```yaml
name: release-apk

on:
  push:
    tags: ["app-v*"] # 예: app-v1.0.0

permissions:
  contents: read # 빌드는 읽기만. 릴리스를 만드는 작업에만 쓰기를 준다

jobs:
  build:
    runs-on: ubuntu-24.04
    environment: release # 내가 승인해야 비밀 값을 읽는다
    permissions:
      contents: read
      id-token: write # 만든 곳 증명(attestation)
      attestations: write
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.35.6" # 개발에 쓰는 버전과 같게
          channel: stable
      - run: flutter pub get --enforce-lockfile
      - run: flutter analyze
      - run: flutter test

      - name: Signing key
        env:
          KEYSTORE: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        run: |
          test -n "$KEYSTORE" # 없으면 여기서 멈춘다. 디버그 키로 서명되면 안 된다
          printf '%s' "$KEYSTORE" | base64 --decode > "$RUNNER_TEMP/release.jks"
          {
            printf 'storeFile=%s\n' "$RUNNER_TEMP/release.jks"
            printf 'storePassword=%s\n' "$STORE_PASSWORD"
            printf 'keyAlias=%s\n' "$KEY_ALIAS"
            printf 'keyPassword=%s\n' "$KEY_PASSWORD"
          } > android/key.properties

      - name: Build
        env:
          API_BASE_URL: ${{ vars.API_BASE_URL }}
          TAG: ${{ github.ref_name }}
          NUMBER: ${{ github.run_number }}
        run: |
          case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL must be https"; exit 1 ;; esac
          flutter build apk --release --split-per-abi \
            --build-name="${TAG#app-v}" --build-number="$NUMBER" \
            --dart-define=API_BASE_URL="$API_BASE_URL"

      - name: Check the signature
        run: |
          APK=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
          TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
          "$TOOLS/apksigner" verify --print-certs "$APK" | tee cert.txt
          if grep -q "Android Debug" cert.txt; then echo "signed with the debug key"; exit 1; fi

      - name: Collect
        run: |
          mkdir -p out
          cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk out/
          cd out && sha256sum *.apk > SHA256SUMS.txt
      - uses: actions/attest-build-provenance@v2
        with:
          subject-path: apps/mobile/out/*.apk
      - uses: actions/upload-artifact@v4
        with:
          name: apk
          path: apps/mobile/out
      - if: always()
        run: rm -f android/key.properties "$RUNNER_TEMP/release.jks"

  draft:
    needs: build
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: apk
          path: out
      - name: Draft release
        env:
          GH_TOKEN: ${{ github.token }}
          TAG: ${{ github.ref_name }}
        run: |
          gh release create "$TAG" out/* --repo "$GITHUB_REPOSITORY" \
            --draft --prerelease --verify-tag --title "$TAG" \
            --notes "비공식 데모 앱입니다. Cypress.io와 제휴, 보증, 후원 관계가 없습니다. 지어낸 정보만 넣어 주세요."
```

이렇게 나눈 까닭:

- **서명 키를 읽는 작업과 릴리스를 쓰는 작업을 나눴다.** 하나가 뚫려도 다른 권한은 없다.
- **초안(draft)까지만 자동이다.** 공개 단추는 내가 누른다.
- **디버그 키면 실패한다.** 지금 Gradle 설정은 키가 없으면 디버그 키로 조용히 서명한다(경고만). 남에게 주면 안 되는 파일이다.
- 릴리스를 만드는 데 남이 만든 action을 쓰지 않는다(`gh`는 GitHub의 도구다).

### 4-3. 실제로 하는 순서

```bash
git tag app-v1.0.0        # main에서
git push origin app-v1.0.0
```

1. Actions 화면에서 승인한다
2. Releases에 초안이 생긴다
3. APK를 받아 **에뮬레이터와 실제 폰에 설치해 본다**
4. 괜찮으면 공개한다

받는 사람의 확인 방법(원하면): `gh attestation verify <apk> -R wonderwall1995/cypress-realworld-for-portfolio-mobile`

### 4-4. 알아 둘 값

| 항목 | 값 |
| --- | --- |
| 파일 크기 | arm64 하나가 약 18~19MB. GitHub의 파일 하나 제한은 2GiB 미만이라 여유가 크다 |
| 파일 종류 | arm64만 올린다. 요즘 폰은 거의 이것이다. 에뮬레이터로 볼 사람이 있으면 x86_64도 더한다 |
| 버전 | 이름은 태그에서, 번호는 실행 번호에서 온다. **번호가 커져야 덮어 설치된다** |
| `gradlew` | 저장소에 없다(`.gitignore`). `flutter build`가 만들어 주는 것으로 알지만 **Linux에서 확인하지 않았다** |
| Flutter | 이 PC는 3.35.6(사용자 브랜치로 표시됨). 작업 파일은 공식 3.35.6을 쓴다. 차이가 있는지 **미확인** |

## 5. 서명 키 (가장 조심할 것)

- **잃어버리면 같은 앱으로 업데이트할 수 없다.** 받은 사람이 지우고 다시 깔아야 한다. 두 곳(예: 암호 관리자와 오프라인 저장소)에 백업한다.
- 새어 나가면 남이 내 앱인 척 서명할 수 있다. 저장소, 채팅, 스크린샷에 두지 않는다. `.gitignore`가 `*.jks`, `*.keystore`, `key.properties`를 막고 있다(확인함).
- 만드는 명령(내 PC에서, 비밀번호는 물어볼 때 친다):

```bash
keytool -genkeypair -v -keystore release.jks -alias release -keyalg RSA -keysize 4096 -validity 10000
```

- 키의 인증서에는 이름을 적는 칸이 있고 **APK를 받은 사람이 볼 수 있다.** 실명이나 주소를 넣지 않아도 된다.

## 6. Android 개발자 확인 제도 (시점에 영향)

Google 문서에서 읽은 것(2026-11-24 검색):

| 언제 | 무엇 |
| --- | --- |
| 2026-08 | 제한 배포 계정(학생, 취미 개발자. **기기 20대까지**, 신분증과 수수료 없음)과 "고급 설치 흐름" 시작 |
| 2026-09-30 | 브라질, 인도네시아, 싱가포르, 태국에서 시작 |
| 2027 | 전 세계로 확대. **한국의 정확한 날짜는 찾지 못했다** |

- 등록하지 않은 개발자의 앱도 ADB나 고급 흐름으로는 설치할 수 있다고 한다. 다만 **받는 사람이 거쳐야 할 단계와 기다리는 시간**이 늘어난다. 면접관에게는 문턱이 된다.
- 한국에 적용되기 전이면 지금처럼 "알 수 없는 앱 설치 허용"만으로 설치될 것으로 본다(미확인).
- **권하는 것:** 1단계를 하면서 제한 배포 계정을 알아본다. 20대면 포트폴리오에 충분하다. 어느 계정이든 앱의 이름표(applicationId)와 서명 키를 등록하게 되므로, **키를 먼저 정해야** 한다.
- 설치가 부담스러운 사람을 위해 **README에 화면 영상이나 GIF**를 함께 두는 것이 좋다.

## 7. 정할 것

| 번호 | 질문 | 추천 |
| --- | --- | --- |
| 1 | 자동(가)인가, 내 PC(나)인가 | 처음은 나, 그다음 가 |
| 2 | 서명 키를 GitHub 비밀 값으로 올려도 되는가 | 승인 환경을 두면 괜찮다고 본다. 꺼려지면 나로 계속 |
| 3 | 릴리스 작업에서 analyze와 test를 돌리는가 | 예 |
| 4 | 공개 시점을 실제 폰 확인 뒤로 하는가 | 예 |
| 5 | 릴리스 전에 Appium 시험을 통과해야 하는가 | 처음에는 내 PC에서 돌려 결과를 릴리스 글에 적는다. GitHub에서 에뮬레이터를 돌리는 것은 나중 |
| 6 | 제한 배포 계정을 만드는가 | 예 (2027년 전) |

## 8. 확인하지 못한 것

- 작업 파일을 한 번도 돌리지 않았다. Linux에서의 빌드도 해 보지 않았다.
- 배포 서버에 release 앱으로 로그인하는 것, 실제 폰의 설치와 업데이트.
- GitHub의 공개 저장소 실행 시간 요금은 이번에 공식 문서로 다시 확인하지 않았다(무료로 알고 있다).
- 개발자 확인 제도의 한국 적용일과 고급 흐름의 정확한 대기 시간.

## 근거

- [Android developer verification](https://developer.android.com/developer-verification), [FAQ](https://developer.android.com/developer-verification/guides/faq?hl=en), [2026-03 블로그](https://android-developers.googleblog.com/2026/03/android-developer-verification.html), [2026-06 블로그](https://android-developers.googleblog.com/2026/06/android-developer-verification.html)
- GitHub: [릴리스와 파일 제한](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases), [배포 환경과 승인](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments), [만든 곳 증명](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds), [안전한 사용](https://docs.github.com/en/actions/reference/security/secure-use)
