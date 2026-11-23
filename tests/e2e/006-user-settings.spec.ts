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
import type { FundedUser } from "./api/create-funded-user";
import { createUsersWithApi } from "./api/create-users";
import { getMeWithApi, Me } from "./api/get-me";
import { getMyBalanceWithApi } from "./api/get-my-balance";
import { hardDeleteBankAccountsWithApi } from "./api/hard-delete-bank-accounts";
import type { Person } from "./api/person";
import { openApp } from "./common/open-app";
import { expectHiddenOnScreen, expectTextInsideOnScreen, expectTextOnScreen, expectTypedOnScreen } from "./common/screen/expect-control";
import { expectScreen } from "./common/screen/expect-screen";
import { scrollTo } from "./common/screen/scroll-to";
import { tap } from "./common/screen/tap";
import { signIn } from "./common/signin";
import { fillUserSettings, openUserSettings, saveUserSettings } from "./common/user-settings";
import { Profile, randomProfile } from "./fixture/random-profile";

const LABEL = "user-settings";
const START_DOLLARS = 100; // 처음에 계좌에 넣은 돈. 정보를 고쳐도 잔액은 그대로여야 한다

// 서버의 내 정보를 설정 화면의 모양으로 바꾼다 (비운 값은 서버에서 null, 화면에서 빈 글자다)
const profileOf = (me: Me): Profile => ({
  lastName: me.lastName,
  firstName: me.firstName,
  email: me.email ?? "",
  phoneNumber: me.phoneNumber ?? "",
});

describe("6. 사용자 설정", () => {
  const people: Person[] = [];

  afterEach(async () => {
    for (const who of people.splice(0)) await hardDeleteBankAccountsWithApi(who);
  });

  // 내 계좌 탭에서 이름을 본다. 탭을 누르면 앱이 내 정보를 다시 읽는다
  const expectNameOnScreen = async (profile: Profile) => {
    await tap("sidenav-my-account");
    await expectTextOnScreen("my-account-full-name", `${profile.lastName} ${profile.firstName}`);
  };

  it("6. 사용자 설정: 정보를 고치고 되돌릴 수 있고, 잘못된 정보는 화면과 서버 모두에서 거절된다", async () => {
    // 준비 (API): A와 남(B)을 만든다. 가입할 때의 정보가 처음 값이다. 가입에는 이메일이 없으므로 비어 있다
    const { A, B } = await createUsersWithApi(["A", "B"], START_DOLLARS, LABEL);
    people.push(A, B);
    const signedUp = ({ user }: FundedUser): Profile => ({
      lastName: user.lastName,
      firstName: user.firstName,
      email: "",
      phoneNumber: user.phoneNumber,
    });
    const original = signedUp(A);
    const changed = randomProfile();

    // 1) 화면: 로그인하면 내 계좌에 가입한 이름과 아이디가 보인다. 설정 화면을 연다 (공통 코드)
    await openApp();
    await signIn(A.user);
    await expectScreen("home");
    await expectNameOnScreen(original);
    await expectTextOnScreen("my-account-username", `@${A.user.username}`);
    await openUserSettings();

    // 2) 거절 (화면): 빈 이름, 잘못된 이메일, 잘못된 전화번호는 저장을 누르면 안내가 나오고 보내지 않는다
    //    (웹은 저장 버튼이 꺼진다. 앱은 누르면 안내가 나오므로, 서버 값이 그대로인 것까지 본다)
    // 3) 거절 (서버): 같은 값을 직접 보내도 거절한다 (422). 화면처럼 모든 값을 함께 보낸다
    for (const [item, wrong, message] of [
      ["firstName", "", "이름을 입력하세요."],
      ["email", "not-an-email", "올바른 이메일 주소를 입력하세요."],
      ["phoneNumber", "abc", "전화번호가 올바르지 않습니다. (예: 010-1234-5678)"],
    ] as const) {
      await fillUserSettings({ [item]: wrong });
      await tap("user-settings-submit");
      await scrollTo(`user-settings-${item}-input`);
      await expectTextInsideOnScreen("user-settings-form", message);
      await expectHiddenOnScreen("user-settings-message");
      expect(profileOf(await getMeWithApi(A))).toEqual(original);
      const refused = await A.api.patch(`/api/users/${A.user.id}`, { data: { ...original, [item]: wrong } });
      expect(refused.status()).toBe(422);
      await fillUserSettings({ [item]: original[item] });
    }
    //    웹에만 (006): 공백뿐인 성, 남의 정보 고치기(403), 아이디와 잔액 함께 보내기. 화면에 짝이 없다
    expect(profileOf(await getMeWithApi(A))).toEqual(original);
    expect(await getMyBalanceWithApi(A)).toBe(START_DOLLARS * 100);

    // 4) 수정 (화면): 이름, 이메일, 전화번호를 고쳐 저장하면 내 계좌의 이름이 바뀐다
    await saveUserSettings(changed);
    //    서버 판정: 서버의 값도 고친 값과 같다
    expect(profileOf(await getMeWithApi(A))).toEqual(changed);
    await driver.back();
    await expectNameOnScreen(changed);

    // 5) 다시 읽어도 고친 값이다: 설정 화면을 다시 열면 칸에 고친 값이 들어 있다
    await openUserSettings();
    for (const [item, value] of Object.entries(changed)) {
      await scrollTo(`user-settings-${item}-input`);
      await expectTypedOnScreen(`user-settings-${item}-input`, value);
    }

    // 6) 되돌리기 (화면): 처음 정보로 되돌린다. 이메일을 비우는 것도 저장된다
    await saveUserSettings(original);
    expect(profileOf(await getMeWithApi(A))).toEqual(original);
    await driver.back();
    await expectNameOnScreen(original);

    // 7) A의 일은 남의 정보를 바꾸지 않았다 (서버)
    expect(profileOf(await getMeWithApi(B))).toEqual(signedUp(B));
  });
});
