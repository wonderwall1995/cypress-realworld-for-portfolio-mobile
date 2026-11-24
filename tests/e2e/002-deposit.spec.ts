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
import { createBankAccountsWithApi } from "./api/create-bank-accounts";
import { expectProfileBalanceIsAccountSumWithApi } from "./api/expect-profile-balance";
import { getBankAccountsWithApi } from "./api/get-bank-accounts";
import { hardDeleteBankAccountsWithApi } from "./api/hard-delete-bank-accounts";
import type { Person } from "./api/person";
import { deposit, openDeposit } from "./common/deposit";
import { expectProfileBalanceOnScreen } from "./common/expect-profile-balance-on-screen";
import { goToMain } from "./common/go-to-main";
import { moneyText } from "./common/money-text";
import { expectHiddenOnScreen, expectTextInsideOnScreen, expectTextOnScreen } from "./common/screen/expect-control";
import { byId } from "./common/screen/find";
import { scrollTo } from "./common/screen/scroll-to";
import { tap } from "./common/screen/tap";
import { typeInto } from "./common/screen/type-into";
import { getMoneyRowsInDb } from "./db/get-money-rows";
import { random } from "./fixture/random";

const LABEL = "deposit";
const BANK_ACCOUNTS = 3; // 입금 시험에 쓰는 계좌 수 (앱의 최대는 60개)
const DEPOSIT_DOLLARS = 100;
const MAX_DEPOSIT_DOLLARS = 21_474_836; // 앱이 한 번에 받는 입금액의 최대

describe("2. 입금", () => {
  const people: Person[] = [];

  afterEach(async () => {
    for (const who of people.splice(0)) await hardDeleteBankAccountsWithApi(who);
  });

  it("2. 입금: 계좌마다 입금하고, 경계값과 금액 구간을 시험한다", async () => {
    const A = await goToMain(LABEL);
    people.push(A);

    // 준비: 자기 계좌를 만든다. 계좌 만들기 자체는 001이 시험하므로, 여기서는 API로 빠르게 3개를 만든다
    await createBankAccountsWithApi(A, BANK_ACCOUNTS);
    await tap("sidenav-bankaccounts"); // API로 만든 계좌를 화면이 다시 읽게 한다
    const accounts = await getBankAccountsWithApi(A);
    expect(accounts.length).toBe(BANK_ACCOUNTS);

    // 계좌마다 "지금 있어야 할 금액"(센트)을 적어 둔다. 처음 값은 입금 전 금액이다 (새 계좌라 0)
    const expected = new Map(accounts.map((account) => [account.id, account.balance]));

    // 이 계좌의 금액이 expected와 같은지 화면과 API로 확인한다
    const expectBalance = async (accountId: string) => {
      const expectedCents = expected.get(accountId)!;
      await tap("sidenav-bankaccounts");
      await scrollTo(`bankaccount-balance-${accountId}`);
      await expectTextOnScreen(`bankaccount-balance-${accountId}`, `잔액 ${moneyText(expectedCents)}`);
      const found = (await getBankAccountsWithApi(A)).find((account) => account.id === accountId);
      expect(found?.balance).toBe(expectedCents);
    };

    // 입금하고, expected를 올린 뒤, 화면과 API의 금액을 확인한다
    const depositAndExpect = async (accountId: string, dollars: number) => {
      await deposit(accountId, dollars);
      expected.set(accountId, expected.get(accountId)! + dollars * 100);
      await expectBalance(accountId);
    };

    // 화면이 막는 금액: 누르면 안내가 나오고 보내지 않는다. 금액도 DB의 행도 그대로다
    // (웹은 입금 버튼이 꺼진다. 앱은 누르면 안내가 나오므로, 보내지 않았다는 것까지 본다)
    const expectDepositRefused = async (accountId: string, amountText: string, notice: string) => {
      const before = await getMoneyRowsInDb(A);
      await openDeposit(accountId);
      await typeInto("deposit-amount-input", amountText);
      await tap("deposit-submit-button");
      await expectTextInsideOnScreen("deposit-dialog", notice);
      await tap("deposit-cancel-button");
      await expectHiddenOnScreen("deposit-dialog");
      await expectBalance(accountId);
      expect(await getMoneyRowsInDb(A)).toEqual(before);
    };

    // 입력은 맞지만 서버가 거절하는 금액: 서버의 거절 안내가 보이며, 금액도 DB의 행도 그대로다
    const expectDepositRefusedByServer = async (accountId: string, dollars: number) => {
      const before = await getMoneyRowsInDb(A);
      await openDeposit(accountId);
      await typeInto("deposit-amount-input", String(dollars));
      await tap("deposit-submit-button");
      await byId("deposit-error").waitForDisplayed();
      await tap("deposit-cancel-button");
      await expectHiddenOnScreen("deposit-dialog");
      await expectBalance(accountId);
      expect(await getMoneyRowsInDb(A)).toEqual(before);
    };

    // 1) 계좌마다 100달러를 입금한다
    for (const account of accounts) {
      await depositAndExpect(account.id, DEPOSIT_DOLLARS);
    }
    //    DB 판정: 입금 하나에 입출금 행 하나, 거래 행 하나다
    expect(await getMoneyRowsInDb(A)).toEqual({ transactions: BANK_ACCOUNTS, bankTransfers: BANK_ACCOUNTS });

    // 2) 금액 구간 (구간 안의 값은 무작위): 작은 금액과 큰 금액 하나씩
    //    웹에만 (002): 구간 다섯 개 모두. 금액의 크기에 따라 앱이 달라지는 곳은 쉼표가 있는 표시뿐이다
    await depositAndExpect(accounts[0].id, random(1, 10));
    await depositAndExpect(accounts[2].id, random(10000, 100000));

    // 경계값 (첫 번째 계좌): 1달러 이상 21,474,836달러 이하의 양 끝과 그 바로 바깥
    const first = accounts[0].id;

    // 최소값: -1달러와 0달러는 거절되고 1달러는 된다
    await expectDepositRefused(first, "-1", "금액은 1달러 이상이어야 합니다.");
    await expectDepositRefused(first, "0", "금액은 1달러 이상이어야 합니다.");
    await depositAndExpect(first, 1);

    // 최대값: 한 단계 위는 입력 단계에서, 최대 입금액은 총 잔액 한도 때문에 서버가 거절한다
    await expectDepositRefused(first, String(MAX_DEPOSIT_DOLLARS + 1), "금액은 21,474,836달러 이하여야 합니다.");
    await expectDepositRefusedByServer(first, MAX_DEPOSIT_DOLLARS);

    // 화면이 막은 바로 그 금액을 서버에 직접 보내도 거절한다. 화면이 막는 것만으로는 서버가 막는다는 증명이 아니다
    const before = await getMoneyRowsInDb(A);
    const answered: Record<string, number> = {};
    for (const amount of [-1, 0, MAX_DEPOSIT_DOLLARS + 1, MAX_DEPOSIT_DOLLARS]) {
      const response = await A.api.post("/api/bankTransfers", {
        data: { bankAccountId: first, amount, type: "deposit" },
      });
      answered[`${amount}달러`] = response.status();
    }
    expect(answered).toEqual({
      "-1달러": 422,
      "0달러": 422,
      "21474837달러": 400,
      "21474836달러": 400,
    });
    expect(await getMoneyRowsInDb(A)).toEqual(before);
    await expectBalance(first);

    // 프로필 잔액: 내 잔액은 계좌 금액의 합이다. 기대 합계는 이 시험이 넣은 금액으로 계산한다
    const expectedSum = [...expected.values()].reduce((sum, cents) => sum + cents, 0);
    expect(await expectProfileBalanceIsAccountSumWithApi(A)).toBe(expectedSum);
    await expectProfileBalanceOnScreen(expectedSum);

    // 최대값의 안쪽: 잔액이 0이면 최대 입금액이 한 번에 들어간다. 거기에 1달러를 더 넣으면 서버가 거절한다
    await hardDeleteBankAccountsWithApi(A);
    await createBankAccountsWithApi(A, 1);
    await tap("sidenav-bankaccounts");
    const [empty] = await getBankAccountsWithApi(A);
    expected.set(empty.id, empty.balance);
    await depositAndExpect(empty.id, MAX_DEPOSIT_DOLLARS);
    await expectDepositRefusedByServer(empty.id, 1);
    expect(await expectProfileBalanceIsAccountSumWithApi(A)).toBe(MAX_DEPOSIT_DOLLARS * 100);
  });
});
