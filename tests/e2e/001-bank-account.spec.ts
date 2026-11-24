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
import { depositWithApi } from "./api/deposit";
import { expectProfileBalanceIsAccountSumWithApi } from "./api/expect-profile-balance";
import { getBankAccountRowsWithApi } from "./api/get-bank-account-rows";
import { getBankAccountsWithApi } from "./api/get-bank-accounts";
import { hardDeleteBankAccountsWithApi } from "./api/hard-delete-bank-accounts";
import type { Person } from "./api/person";
import { createBankAccount, deleteBankAccount, expectBankAccountOnScreen, openBankAccounts } from "./common/bank-account";
import { goToMain } from "./common/go-to-main";
import {
  expectDisabledInsideOnScreen,
  expectDisabledOnScreen,
  expectEnabledOnScreen,
  expectHiddenOnScreen,
  expectRowCountOnScreen,
  expectTextOnScreen,
} from "./common/screen/expect-control";
import { byId } from "./common/screen/find";
import { scrollTo } from "./common/screen/scroll-to";
import { getBankAccountBalancesInDb } from "./db/get-bank-account-balances";
import { random } from "./fixture/random";

const LABEL = "bank-account";
const MAX_BANK_ACCOUNTS = 60; // 앱이 한 사용자에게 허용하는 계좌 수의 최대
const ROW = "bankaccount-list-item-";

describe("1. 은행 계좌", () => {
  const people: Person[] = [];

  afterEach(async () => {
    for (const who of people.splice(0)) await hardDeleteBankAccountsWithApi(who);
  });

  it("1. 은행 계좌: 소량은 화면으로, 대량은 API로, 59~61번째 경계는 화면으로 시험한다", async () => {
    // 0) 자기 계정을 만들고 홈에서 시작한다. 새 사람이라 계좌 행이 없다
    const A = await goToMain(LABEL);
    people.push(A);
    expect(await getBankAccountRowsWithApi(A)).toEqual({ total: 0, visible: 0, hidden: 0 });
    await openBankAccounts();

    // 1) 소량(1~3개 만들기, 만든 수 이하만큼 삭제): 화면이 판정하고, 삭제는 숨김(soft delete)으로 남는지 확인한다
    const createCount = random(1, 3);
    const deleteCount = random(1, createCount);

    // 1-1) 화면으로 만든다. 만들 때마다 그 계좌가 실제로 있고 금액이 0인지 API로 확인한다 (공통 코드가 한꺼번에 한다)
    const created = [];
    for (let count = 0; count < createCount; count += 1) {
      created.push(await createBankAccount(A));
    }
    // 화면 확인: 만든 계좌가 모두 목록에 있고, 개수가 맞다
    for (const account of created) await expectBankAccountOnScreen(account);
    await expectRowCountOnScreen(ROW, createCount);

    // 1-2) 화면에서 deleteCount개를 삭제한다. 삭제는 지우는 것이 아니라 숨기는 것이다
    const deleted = created.slice(0, deleteCount);
    const kept = created.slice(deleteCount);
    for (const account of deleted) await deleteBankAccount(account.id);

    // 화면 확인: 목록을 다시 읽어도 삭제한 계좌는 없고, 남긴 계좌는 그대로 있다
    await openBankAccounts();
    for (const account of kept) await expectBankAccountOnScreen(account);
    for (const account of deleted) await expectHiddenOnScreen(`${ROW}${account.id}`);
    await expectRowCountOnScreen(ROW, kept.length);

    // API 확인: 앱의 목록에는 남긴 계좌만 나온다. DB 확인: 삭제한 계좌의 행은 숨은 채로 남아 있다
    expect((await getBankAccountsWithApi(A)).map(({ id }) => id).sort()).toEqual(kept.map(({ id }) => id).sort());
    expect(await getBankAccountRowsWithApi(A)).toEqual({ total: createCount, visible: kept.length, hidden: deleteCount });
    expect(Object.keys(await getBankAccountBalancesInDb(A)).sort()).toEqual(created.map(({ id }) => id).sort());

    // 2) 대량(연속 생성): API로 58개가 될 때까지 만들고, 화면은 목록을 끝까지 읽을 수 있는지만 본다
    //    목록에는 화면에 보이는 줄만 있으므로, 개수는 API로 보고 화면은 처음과 마지막 줄을 찾아본다
    await createBankAccountsWithApi(A, MAX_BANK_ACCOUNTS - 2);
    await openBankAccounts();
    const list = await getBankAccountsWithApi(A);
    expect(list.length).toBe(MAX_BANK_ACCOUNTS - 2);
    await scrollTo(`${ROW}${list[list.length - 1].id}`);
    await scrollTo(`${ROW}${list[0].id}`);

    // 3) 경계값 59 ~ 61번째 (화면): 59번째와 60번째는 만들어지고, 61번째는 만들 수 없다
    for (const count of [MAX_BANK_ACCOUNTS - 1, MAX_BANK_ACCOUNTS]) {
      await expectEnabledOnScreen("bankaccount-new");
      const account = await createBankAccount(A);
      await expectBankAccountOnScreen(account);
      expect((await getBankAccountsWithApi(A)).length).toBe(count);
    }

    // 61번째: 화면은 "만들기" 버튼을 끄고 안내를 보여 주며, 서버도 거절한다. 계좌는 그대로 60개다
    await expectDisabledOnScreen("bankaccount-new");
    await byId("bankaccount-limit").waitForDisplayed();
    const refused = await A.api.post("/api/bankAccounts", {
      data: { bankName: "한도 시험", accountNumber: "123456789" },
    });
    expect(refused.status()).toBe(400);
    expect((await getBankAccountRowsWithApi(A)).visible).toBe(MAX_BANK_ACCOUNTS);

    // 4) 거절: 잔액이 있는 계좌의 삭제. 삭제하면 그 돈이 사라지므로 막아야 한다
    //    준비: 계좌 하나에 API로 1달러를 넣는다 (입금 자체는 002가 시험한다)
    const [rich] = await getBankAccountsWithApi(A);
    await depositWithApi(A, rich.id, 1);
    await openBankAccounts();
    //    화면: 그 계좌의 삭제 버튼이 꺼진다
    await scrollTo(`bankaccount-balance-${rich.id}`);
    await expectDisabledInsideOnScreen(`${ROW}${rich.id}`, "bankaccount-delete");
    //    서버: 같은 삭제를 직접 보내도 거절한다 (400). 계좌는 그대로 보이고 돈도 그대로다
    const deleteRefused = await A.api.delete(`/api/bankAccounts/${rich.id}`);
    expect(deleteRefused.status()).toBe(400);
    expect((await getBankAccountsWithApi(A)).find((account) => account.id === rich.id)?.balance).toBe(100);
    expect((await getBankAccountRowsWithApi(A)).visible).toBe(MAX_BANK_ACCOUNTS);
    expect(await expectProfileBalanceIsAccountSumWithApi(A)).toBe(100);

    // 5) 대량(연속 삭제): API로 숨긴 행까지 모두 완전히 지우고, 화면은 빈 목록을 읽을 수 있는지만 본다
    await hardDeleteBankAccountsWithApi(A);
    await openBankAccounts();
    await expectTextOnScreen("bankaccount-list-empty", "등록된 은행 계좌가 없습니다.");
    await expectRowCountOnScreen(ROW, 0);
    expect(await getBankAccountRowsWithApi(A)).toEqual({ total: 0, visible: 0, hidden: 0 });
  });
});
