import { Profile } from "../fixture/random-profile";
import { step } from "../fixture/step";
import { expectTextOnScreen } from "./screen/expect-control";
import { byId } from "./screen/find";
import { scrollTo } from "./screen/scroll-to";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/** 공통 코드: 더보기 메뉴의 "설정"을 눌러 설정 화면을 연다. 설정 칸이 보이면 끝난다. */
export async function openUserSettings() {
  return step("common", "openUserSettings", async () => {
    await tap("sidenav-more");
    await tap("sidenav-user-settings");
    await byId("user-settings-form").waitForDisplayed();
  });
}

/**
 * 공통 코드: 설정 화면에 정보를 쓴다. 준 항목만 쓴다.
 * 쓰기만 한다: 안내가 나오는지는 부른 쪽이 판정한다.
 */
export async function fillUserSettings(profile: Partial<Profile>) {
  return step("common", "fillUserSettings", async () => {
    for (const [item, value] of Object.entries(profile)) {
      await typeInto(`user-settings-${item}-input`, value);
    }
  });
}

/**
 * 공통 코드: 설정 화면에 정보를 쓰고 저장한다.
 * 저장됐다는 안내가 나오는 것으로 동작이 됐는지 확인한다. 저장된 값은 부른 쪽이 판정한다.
 */
export async function saveUserSettings(profile: Profile) {
  return step("common", "saveUserSettings", async () => {
    await fillUserSettings(profile);
    await tap("user-settings-submit");
    await scrollTo("user-settings-message");
    await expectTextOnScreen("user-settings-message", "설정 저장 성공");
  });
}
