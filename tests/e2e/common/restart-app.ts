import { driver } from "@wdio/globals";
import { step } from "../fixture/step";
import { APP } from "./open-app";

/** 공통 코드: 앱을 껐다 켠다. 데이터는 그대로다. 어느 화면이 열리는지는 부른 쪽이 판정한다 (웹의 새로고침 자리) */
export async function restartApp() {
  return step("common", "restartApp", async () => {
    await driver.execute("mobile: terminateApp", { appId: APP });
    await driver.execute("mobile: activateApp", { appId: APP });
  });
}
