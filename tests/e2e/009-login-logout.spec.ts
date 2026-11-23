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

import { driver, expect } from "@wdio/globals";
import { createFundedUserWithApi, FundedUser } from "./api/create-funded-user";
import { getMyBalanceWithApi } from "./api/get-my-balance";
import { hardDeleteBankAccountsWithApi } from "./api/hard-delete-bank-accounts";
import type { Person } from "./api/person";
import { newApiSession } from "./api/session";
import { openBankAccounts } from "./common/bank-account";
import { expectProfileBalanceOnScreen } from "./common/expect-profile-balance-on-screen";
import { APP, openApp } from "./common/open-app";
import { restartApp } from "./common/restart-app";
import { expectHiddenOnScreen, expectTextInsideOnScreen, expectTextOnScreen } from "./common/screen/expect-control";
import { expectScreen } from "./common/screen/expect-screen";
import { byId } from "./common/screen/find";
import { signIn } from "./common/signin";
import { signOut } from "./common/signout";
import { randomDigits } from "./fixture/random";
import { randomBankAccountInput } from "./fixture/random-bank-account";
import { runUser } from "./fixture/run-user";

const LABEL = "login-logout";
const A_DOLLARS = 1000; // 두 사람의 돈을 다르게 두어, 화면에 누구의 잔액이 보이는지 구별한다
const B_DOLLARS = 500;
const WRONG_LOGIN = "사용자 ID 또는 비밀번호가 올바르지 않습니다."; // 무엇이 틀렸는지는 알려 주지 않는다

describe("9. 로그인 실패와 로그아웃", () => {
  const people: Person[] = [];

  afterEach(async () => {
    for (const who of people.splice(0)) await hardDeleteBankAccountsWithApi(who);
  });

  it("9. 로그인 실패와 로그아웃: 틀린 로그인은 거절되고, 로그아웃하면 화면도 서버도 닫힌다", async () => {
    // 준비 (API): 두 사람을 만든다. 비밀번호는 대소문자를 구별하는지 보려고 글자를 섞는다 (번호의 값을 쓰지 않는다)
    const inputOf = (name: string, letters: string) => ({
      user: { ...runUser(LABEL, name), password: `${letters}${randomDigits(4)}` },
      account: randomBankAccountInput(),
    });
    const A = await createFundedUserWithApi(A_DOLLARS, inputOf("A", "Aa"));
    const B = await createFundedUserWithApi(B_DOLLARS, inputOf("B", "Bb"));
    people.push(A, B);
    const { username, password } = A.user;
    const accountOf = (who: FundedUser) => `bankaccount-list-item-${who.account.id}`;
    const apiLogin = async (data: object) => (await newApiSession().post("/api/login", { data })).status();

    // 1) 웹에만 (009): 로그인 10가지 표와 보호된 API 6개. 화면과 짝이 되는 것만 3), 4), 9)에서 보낸다
    // 2) 웹에만 (009): 보호된 주소를 직접 열기. 앱에는 주소가 없다

    // 3) 화면: 비밀번호가 4자보다 짧으면 누를 때 안내가 나오고 로그인 화면에 머문다 (웹은 버튼이 꺼진다)
    await openApp();
    await signIn({ username, password: "123" });
    await expectTextInsideOnScreen("android:id/content", "비밀번호는 4자 이상이어야 합니다.");
    await expectScreen("signin");

    // 4) 화면: 틀린 비밀번호로 로그인하면 안내가 나오고 로그인 화면에 머문다. 서버에 같은 값을 직접 보내도 거절한다 (401)
    await signIn({ username, password: "wrong-password" });
    await expectTextOnScreen("signin-error", WRONG_LOGIN);
    await expectScreen("signin");
    expect(await apiLogin({ username, password: "wrong-password" })).toBe(401);
    //    대소문자만 다른 비밀번호도 틀린 비밀번호다 (화면이 글자를 바꿔 보내지 않는다)
    await signIn({ username, password: password.toLowerCase() });
    await expectTextOnScreen("signin-error", WRONG_LOGIN);
    expect(await apiLogin({ username, password: password.toLowerCase() })).toBe(401);

    // 5) 실패한 뒤에도 맞는 비밀번호로는 로그인된다. 앞의 안내는 사라지고, 내 계좌에 A의 이름과 잔액이 보인다
    await signIn(A.user);
    await expectScreen("home");
    await expectHiddenOnScreen("signin-error");
    await expectProfileBalanceOnScreen(A_DOLLARS * 100);
    await expectTextOnScreen("my-account-username", `@${username}`);
    expect(await getMyBalanceWithApi(A)).toBe(A_DOLLARS * 100);

    // 6) A가 자기 은행 계좌를 보다가 로그아웃한다. 로그인 화면이 되고, 앱을 껐다 켜도 로그인 화면이다
    //    웹에만 (009): 로그아웃한 쿠키로 API를 부르기. 앱의 쿠키는 테스트가 볼 수 없다
    await openBankAccounts();
    await byId(accountOf(A)).waitForDisplayed();
    await signOut();
    await expectHiddenOnScreen("sidenav-home");
    await restartApp();
    await expectScreen("signin");

    // 7) 이어서 B가 로그인하면 B의 것만 보인다. 앞서 쓴 A의 이름, 잔액, 계좌는 남아 있지 않다
    await signIn(B.user);
    await expectScreen("home");
    await expectProfileBalanceOnScreen(B_DOLLARS * 100);
    await expectTextOnScreen("my-account-username", `@${B.user.username}`);
    await openBankAccounts();
    await byId(accountOf(B)).waitForDisplayed();
    await expectHiddenOnScreen(accountOf(A));

    // 8) B도 로그아웃한다. 뒤로 가기와 껐다 켜기로도 로그인한 화면은 다시 열리지 않는다
    await signOut();
    await driver.back(); // 로그인 화면에서 뒤로 가면 앱 밖으로 나간다
    await driver.execute("mobile: activateApp", { appId: APP });
    await expectScreen("signin");
    await restartApp();
    await expectScreen("signin");

    // 9) 없는 아이디로 로그인해도 틀린 비밀번호와 안내가 같다. 서버의 답도 같다 (401)
    await expectHiddenOnScreen("signin-error");
    await signIn({ username: `${username}-none`, password });
    await expectTextOnScreen("signin-error", WRONG_LOGIN);
    expect(await apiLogin({ username: `${username}-none`, password })).toBe(401);
  });
});
