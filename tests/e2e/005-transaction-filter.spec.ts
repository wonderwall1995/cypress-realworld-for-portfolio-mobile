/**
 * ===== 테스트 코드 공통 머리말 (App) =====
 * 원본은 testcode.template.ts 이다. 모든 *.spec.ts 의 맨 위에 이 글을 똑같이 둔다. 고칠 때는 원본과 모든 사본을 함께 고친다.
 * 웹 저장소의 공통 머리말과 짝이다. [앱]이 붙은 줄은 웹과 다른 줄이다.
 *
 * [세팅]
 * - [앱] 도구: Wdio + Appium (UiAutomator2), TypeScript. 설정은 wdio.conf.ts 에 있다.
 * - 파일 이름: NNN-이름.spec.ts. 웹과 같은 시험은 같은 번호를 쓴다. 번호는 읽는 순서일 뿐, 실행 순서를 약속하지 않는다.
 * - [앱] 제한 시간: 테스트 하나에 8분 (화면이 웹보다 느리다).
 * - [앱] 서버: 테스트 전에 API(Express)와 에뮬레이터가 떠 있고 앱이 깔려 있어야 한다. 앱과 테스트는 같은 서버를 본다.
 * - [앱] 폴더: common/ 은 화면 동작 묶음, common/screen/ 은 화면의 바닥 도구, api/ 는 API 도구, db/ 는 DB를 읽는 도구, fixture/ 는 테스트에 쓰는 값을 만드는 도구다. 만드는 법은 [도구 약속]을 따른다.
 *
 * [의도: 주요 테스트 코드 별 생성 목적]
 * - 테스트 파일 하나는 목적 하나를 가진다. 그 목적을 it() 의 제목에 한 줄로 쓴다. 웹에 짝이 있으면 같은 제목을 쓴다.
 * - 파일은 서로 독립이다. 다른 파일의 결과나 실행 순서에 기대지 않는다. [앱] 에뮬레이터가 하나라서 차례대로 돌린다.
 * - 공통 준비(로그인 등)는 common/ 코드로 한다. 그 기능 자체의 시험은 그 기능의 파일 하나만 맡는다. (예: 회원가입은 000-auth 만 시험한다)
 * - [앱] 웹과 같은 단계 번호를 쓴다. 웹에만 두는 단계는 번호를 비우고 "웹에만" 한 줄을 남긴다.
 *
 * [설계 공통]
 * - [앱] 시작: 앱의 데이터를 비우고 켠다 (웹의 새 브라우저와 같다). goToMain 으로 자기 계정을 준비하고 Main 에서 시작한다.
 * - 판정: 한 동작을 화면과 서버 두 곳에서 본다. 둘 다 맞아야 통과한다.
 * - [앱] 서버 판정: API로 본다. API로 볼 수 없는 것만 DB로 본다 (거절된 돈 요청이 행을 남기지 않았는지, 숨긴 행이 남아 있는지).
 * - [앱] API 시험의 범위: 화면과 짝이 되는 것만 한다. 이 줄이 실패하면 앱을 고쳐야 하는가? 아니면 웹이 맡는다.
 * - [앱] 막음은 두 가지다. 버튼이 꺼지는 곳은 꺼짐을 본다. 눌러야 안내가 나오는 곳은 안내와 함께 서버 값이 그대로인지 본다.
 * - 속도: 소량은 화면으로 한다. 대량(연속 생성, 연속 삭제)은 API로 하고, 화면은 그 결과를 읽을 수 있는지만 본다.
 * - [앱] 개수: 목록에는 화면에 보이는 줄만 있다. 개수는 API로 보고, 화면은 "이 줄이 있다"를 스크롤해서 본다.
 * - 삭제: 앱의 화면 삭제는 숨김(soft delete)이다. 있음/없음은 visible 을 생각해서 본다. 완전 삭제는 API 도구로 한다.
 * - 값: 정식 실행은 서버가 준 번호의 값을, 일부 실행은 무작위 값을 쓴다. 경계값은 따로 정해서 시험한다.
 * - [앱] 새로 읽기: API로 바꾼 것은 화면이 모른다. 당겨서 새로고침하거나 탭을 다시 누른다. 앱을 껐다 켜지 않는다.
 * - [앱] 정리: 사람의 계좌를 지우는 일은 afterEach 에 둔다. 중간에 실패해도 치운다.
 * - 실패: 도구는 자기 동작이 됐는지 스스로 확인하므로, 실패한 줄이 곧 원인 지점이다.
 *
 * [도구 약속] (api/, common/, db/, fixture/ 에 도구를 만들 때 지킨다)
 * - [앱] 받는 것: API와 DB 도구의 첫 번째 인자는 사람(A)이다. A 는 { user, account, api } 이고, A.api 는 화면과 별개인 A의 로그인이다. 화면 도구는 사람이나 값만 받는다.
 * - 판정: 동작 도구(만들기, 지우기, 입금 등)는 그 동작이 됐는지만 확인한다. 그 밖의 판정은 이름이 expect 로 시작하는 도구나 spec 의 expect 줄에 둔다.
 * - 돌려주는 것: 만드는 도구는 만든 것(id 포함)을, 읽는 도구는 읽은 값을 돌려준다. 값이 여럿이면 순서가 아니라 이름 붙은 묶음({ A, B, C })으로 돌려준다.
 * - [앱] 이름: 동사로 시작한다(create, get, delete, expect 등). API 도구는 끝에 WithApi, DB 도구는 끝에 InDb, 화면 판정 도구는 끝에 OnScreen 을 붙인다. 화면 동작 도구는 붙이지 않는다.
 * - [앱] 단계: 도구의 몸체를 step("종류", "도구 이름", ...) 으로 감싼다. 종류는 common, api, fixture 중 하나다. DB 도구는 api 로 적는다. 기록기가 이 단계로 도구별 성공/실패를 모은다.
 * - [앱] 화면 확인: expectScreen 의 대표 식별자는 그 화면에만 있고 스크롤해도 남는 것이다 (웹의 toHaveURL 자리).
 * - [앱] 화면: spec 과 common/ 은 식별자만 쓴다. 찾기, 글자 읽기, 쓰기, 꺼짐 읽기, 스크롤은 common/screen/ 의 도구로만 한다.
 * - [앱] 쓰기: 누르고, 포커스를 기다리고, 쓴다. 포커스 없이 쓰면 화면 구조에는 글자가 보이지만 앱은 받지 못한다(거짓 통과).
 * - [앱] 기다림: 정해진 시간을 기다리지 않는다(pause 금지). 보이기를, 포커스가 오기를, 값이 같아지기를 기다린다.
 * - [앱] 사라짐: not.toBeDisplayed() 를 쓰지 않는다(사라진 요소에서 20초 넘게 헛기다린다). expectHiddenOnScreen 으로 사라지기를 기다린다.
 * - [앱] DB: 읽기만 한다. 내 PC의 DB만 본다. 비밀번호 칸은 스키마에 두지 않는다.
 * - 예외: 값만 만드는 함수(fixture/ 의 random 등)와 common/screen/ 의 바닥 도구는 단계로 감싸지 않는다.
 * ===== 공통 머리말 끝 =====
 */

import { expect } from "@wdio/globals";
import { createUsersWithApi } from "./api/create-users";
import { getMyTransactionsWithApi, myTransactionsUrl } from "./api/get-my-transactions";
import { hardDeleteBankAccountsWithApi } from "./api/hard-delete-bank-accounts";
import type { Person } from "./api/person";
import { transferWithApi } from "./api/transfer";
import { openApp } from "./common/open-app";
import {
  expectDisabledOnScreen,
  expectHiddenOnScreen,
  expectRowCountOnScreen,
  expectTextOnScreen,
} from "./common/screen/expect-control";
import { expectScreen } from "./common/screen/expect-screen";
import { byId } from "./common/screen/find";
import { scrollTo } from "./common/screen/scroll-to";
import { tap } from "./common/screen/tap";
import { signIn } from "./common/signin";
import { applyAmountFilter, fillAmountFilter, fillDateFilter } from "./common/transaction-filter";
import { openMyTransactions } from "./common/transaction-tabs";
import { random } from "./fixture/random";
import { fixtureValue, runFixtures } from "./fixture/run-fixtures";

const LABEL = "transaction-filter";
const START_DOLLARS = 1000; // 세 사람이 처음에 계좌에 넣은 돈. 이 입금도 거래 목록에 한 건으로 나온다
const DAY = 24 * 60 * 60 * 1000;
const ROW = "transaction-item-";

// 오늘부터 days일 뒤의 날짜 ("YYYY-MM-DD", 이 컴퓨터의 시간대)
const dayFromToday = (days: number) => {
  const date = new Date(Date.now() + days * DAY);
  const two = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}`;
};

describe("5. 거래 목록 필터", () => {
  const people: Person[] = [];

  afterEach(async () => {
    for (const who of people.splice(0)) await hardDeleteBankAccountsWithApi(who);
  });

  it("5. 거래 목록 필터: 범위 안의 거래만 보이고, 잘못된 범위는 화면과 서버 모두에서 거절된다", async () => {
    // 준비 (API): A가 B와 C에게 보내고, B와 C에게서 받는다.
    //   작은 구간은 $10~$90, 큰 구간은 $250~$390. A의 목록은 이 4건과 처음 입금 1건, 모두 5건이다
    const { A, B, C } = await createUsersWithApi(["A", "B", "C"], START_DOLLARS, LABEL);
    people.push(A, B, C);
    const fixtures = runFixtures(LABEL);
    const dollarsOf = (item: string, min: number, max: number) =>
      fixtures ? Number(fixtureValue(fixtures, item)) : random(min, max);
    const sentSmall = await transferWithApi(A, B, dollarsOf("sentSmallDollars", 10, 90));
    const sentBig = await transferWithApi(A, C, dollarsOf("sentBigDollars", 250, 390));
    const gotSmall = await transferWithApi(B, A, dollarsOf("gotSmallDollars", 10, 90));
    const gotBig = await transferWithApi(C, A, dollarsOf("gotBigDollars", 250, 390));
    const transfers: { id: string }[] = [sentSmall, sentBig, gotSmall, gotBig];
    const all = await getMyTransactionsWithApi(A);
    expect(all.length).toBe(5);
    const opening = all.find((item) => transfers.every((sent) => sent.id !== item.id))!; // 처음 입금

    // 1) 웹에만 (005): 금액의 경계 표. 서버의 규칙이다
    // 2) 웹에만 (005): 날짜의 경계 표. 서버의 규칙이다
    // 3) 웹에만 (005): 입력의 경계 표. 화면과 짝이 되는 값만 6)과 8)에서 보낸다
    // 4) 웹에만 (005): 각자의 관점 표. 서버의 규칙이다

    // 화면: 구간마다 대표 하나만 눈에 보이게 거른다 (A의 화면)
    await openApp();
    await signIn(A.user);
    await expectScreen("home");
    await openMyTransactions();

    // 거른 목록에 이 거래들만 보이는가 (한두 건이라 화면에 다 들어온다. 하나도 없으면 빈 목록 안내가 보인다)
    const expectListOnScreen = async (items: { id: string }[]) => {
      for (const item of items) await byId(`${ROW}${item.id}`).waitForDisplayed();
      await expectRowCountOnScreen(ROW, items.length);
      if (items.length === 0) await byId("transaction-list-empty").waitForDisplayed();
    };
    // 거르지 않은 목록: 새 거래 둘이 위에 보인다. 다섯 건 모두는 처음과 끝에 한 번씩만 끝까지 밀어 본다 (오래 걸린다)
    const expectUnfilteredOnScreen = async () => {
      await byId(`${ROW}${gotBig.id}`).waitForDisplayed();
      await byId(`${ROW}${gotSmall.id}`).waitForDisplayed();
    };
    const expectEverythingOnScreen = async () => {
      await expectUnfilteredOnScreen();
      for (const item of [sentBig, sentSmall, opening]) await scrollTo(`${ROW}${item.id}`);
      await scrollTo(`${ROW}${gotBig.id}`);
    };
    await expectEverythingOnScreen();

    // 5) 금액 구간: 작은 금액, 큰 금액, 해당 없음 (출금과 입금)
    for (const [kind, small, big] of [
      ["withdrawal", sentSmall, sentBig],
      ["deposit", gotSmall, gotBig],
    ] as const) {
      await applyAmountFilter(kind, { min: "1", max: "100" });
      await expectListOnScreen([small]);
      await applyAmountFilter(kind, { min: "200", max: "400" });
      await expectListOnScreen([big]);
      await applyAmountFilter(kind, { min: "500", max: "600" });
      await expectListOnScreen([]);
      await applyAmountFilter(kind, { min: "", max: "" }); // 필터를 없애면 다시 모두 보인다
      await expectUnfilteredOnScreen();
    }

    // 6) 잘못된 금액 구간: 최소가 더 큼, 소수, 한도 초과. 안내가 나오고 적용 버튼이 꺼진다. 서버에 직접 보내도 거절한다 (422)
    for (const [min, max, message, filter] of [
      ["100", "50", "최소 금액이 최대 금액보다 클 수 없습니다", { withdrawalMin: 10000, withdrawalMax: 5000 }],
      ["10.5", "", "숫자(정수)만 입력하세요", { withdrawalMin: "10.5" }],
      ["21474837", "", "21,474,836 이하로 입력하세요", { withdrawalMin: 2147483700 }],
    ] as const) {
      await fillAmountFilter("withdrawal", { min, max });
      await expectTextOnScreen("transaction-list-filter-withdrawal-message", message);
      await expectDisabledOnScreen("transaction-list-filter-withdrawal-apply-button");
      await tap("transaction-list-filter-withdrawal-reset-button");
      await expectHiddenOnScreen("transaction-list-filter-withdrawal");
      await expectUnfilteredOnScreen();
      const refused = await A.api.get(myTransactionsUrl(filter));
      expect(refused.status()).toBe(422);
    }

    // 7) 날짜 구간: 미래 구간은 없음, 오늘이 든 구간은 모두 (어제와 내일로 잡아 자정에도 흔들리지 않는다)
    await fillDateFilter(dayFromToday(10), dayFromToday(20));
    await expectListOnScreen([]);
    await fillDateFilter(dayFromToday(-1), dayFromToday(1));
    await expectUnfilteredOnScreen();

    // 8) 잘못된 날짜 구간: 시작이 늦음, 없는 날짜, 덜 쓴 날짜. 안내가 나온다. 완성된 날짜는 서버에 직접 보내도 거절한다 (422)
    for (const [start, end, message, filter] of [
      [
        "2027-03-02",
        "2027-03-01",
        "시작일이 종료일보다 늦을 수 없습니다",
        { dateRangeStart: "2027-03-02", dateRangeEnd: "2027-03-01" },
      ],
      ["2027-02-30", "", "시작일: 존재하지 않는 날짜입니다", { dateRangeStart: "2027-02-30" }],
      ["2027-02", "", "시작일의 연·월·일을 모두 입력하세요", undefined], // 덜 쓴 날짜는 보낼 값이 없다
    ] as const) {
      await fillDateFilter(start, end);
      await expectTextOnScreen("transaction-list-filter-date-message", message);
      if (filter) {
        const refused = await A.api.get(myTransactionsUrl(filter));
        expect(refused.status()).toBe(422);
      }
    }
    await tap("transaction-list-filter-date-clear-button");
    await expectHiddenOnScreen("transaction-list-filter-date-message");
    await expectEverythingOnScreen();
  });
});
