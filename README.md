# Cypress Realworld For Personal Portfolio Mobile

내 웹 포트폴리오 프로젝트의 결제 앱을 **네이티브 안드로이드(Flutter)** 로 다시 만든 앱입니다. [cypress-realworld-for-portfolio](https://github.com/wonderwall1995/cypress-realworld-for-portfolio)의 **모바일 짝**이고, 그 웹 프로젝트는 Cypress.io의 [Cypress Real World App](https://github.com/cypress-io/cypress-realworld-app)을 개인적으로 포크한 것입니다.

이 앱은 **QA 포트폴리오용 데모 앱**입니다. 테스트하기 좋게 만들었습니다. 테스트가 만지는 모든 위젯에는 고정된 id가 있고, 이름은 웹의 `data-testid`와 같습니다. 테스트 설계는 따로 진행합니다.

| 홈 | 앱 소개 |
| :---: | --- |
| <img src="docs/images/home.png" alt="홈 화면" width="420"> | **홈 화면** (화면 글자는 한국어입니다).<br><br>- **새 거래** 버튼과 **전체 / 친구 / 내 거래** 탭<br>- **날짜 / 금액** 필터 칩 (기간, 금액 범위)<br>- 각 줄: 누가 누구에게 결제하거나 요청했는지, 금액, 좋아요, 댓글<br>- 헤더 오른쪽: **© Cypress.io**(원본 저장소 링크)와 **made by Claude**<br>- 아래 막대: 홈, 알림(안 읽은 개수), 은행 계좌, 내 계좌, 그리고 **더보기** 메뉴(설정, 앱 정보, 로그아웃) |

## 웹 프로젝트와의 관계

- **같은 서버.** 앱은 웹 앱과 같은 Express API, 같은 PostgreSQL 데이터베이스를 씁니다. 웹뷰가 아니라 별도의 화면(UI)입니다.
- **같은 이름.** 웹에 같은 요소가 있으면, 위젯 id는 웹의 `data-testid` 이름을 따릅니다.
- **기준은 웹 레포입니다.** 서버 쪽에서 고칠 것이 있으면 이 레포에서 고치지 않고 웹 레포에 요청합니다.

## 기능과 현재 상태

**Android 에뮬레이터에서 실제 서버로 만들고 확인한 것**

- 로그인(로그인 상태 유지), 회원가입, 로그아웃
- 처음 설정(은행 계좌 만들기), 은행 계좌 목록(추가, 삭제)
- 거래 목록(전체, 친구, 내 거래): 스크롤로 다음 쪽 불러오기, 당겨서 새로고침, 날짜와 금액 필터
- 거래 상세, 새 결제 또는 요청(3단계), 요청 수락 또는 거절
- 좋아요, 댓글, 알림(안 읽은 개수 표시)
- 내 계좌(잔액), 은행 계좌와 잔액 사이의 입금과 출금, 이체 내역
- 설정(이름, 이메일, 전화번호, 새 거래의 기본 공개 범위)
- 라이선스 안내가 있는 앱 정보 화면

**아직 하지 않은 것**

- WebdriverIO와 Appium을 쓰는 end-to-end 테스트
- iOS와 실제 기기는 실행하거나 확인하지 **않았습니다**

## License Compliance

This app is the mobile counterpart of a personal fork of the [Cypress Real World App](https://github.com/cypress-io/cypress-realworld-app) by Cypress.io, distributed under the [MIT License](LICENSE).

- **The original copyright belongs entirely to the Cypress.io team.** The original MIT License text and the copyright notice (Copyright (c) 2020 Cypress.io) are retained in [LICENSE](LICENSE).
- This app is used **solely for non-commercial purposes** (personal learning and portfolio). It is unofficial, and it is not affiliated with, endorsed by, or sponsored by Cypress.io. It is not published to any app store.
- The app name contains "Cypress" only to credit the original project. Cypress logos and trademark images are not used.
- My modifications are shared under the same MIT License.
- The software is provided "as is", without warranty of any kind; see [LICENSE](LICENSE).
- Third-party packages keep their own licenses. They are listed inside the app (**… menu → 앱 정보 → 오픈소스 라이선스**).

## License

[![license](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

This project is licensed under the terms of the [MIT license](LICENSE).
