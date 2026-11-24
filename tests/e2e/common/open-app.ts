import { driver } from "@wdio/globals";
import { step } from "../fixture/step";
import { expectScreen } from "./screen/expect-screen";

/** 시험하는 앱 */
export const APP = "io.github.wonderwall1995.cypress_realworld_for_personal_portfolio_mobile";

/**
 * 공통 코드: 앱의 데이터를 비우고 켠다. 로그인 화면이 보이면 끝난다 (웹의 새 브라우저 자리).
 * 이 기기에 깔린 시험용 앱의 데이터(로그인)만 지운다.
 */
export async function openApp() {
  return step("common", "openApp", async () => {
    await driver.execute("mobile: clearApp", { appId: APP });
    await driver.execute("mobile: activateApp", { appId: APP });
    await expectScreen("signin");
  });
}
