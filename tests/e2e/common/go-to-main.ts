import { createAccountWithApi } from "../api/create-account";
import type { Person } from "../api/person";
import { runUser } from "../fixture/run-user";
import { step } from "../fixture/step";
import { openApp } from "./open-app";
import { expectScreen } from "./screen/expect-screen";
import { signIn } from "./signin";

/**
 * 공통 코드: 테스트를 Main(홈)에서 시작하게 만들고, 이 테스트가 쓰는 사람을 돌려준다.
 * 앱을 비우고 켜고, API로 이 테스트만의 계정을 만들고, 화면에서 로그인해서 홈으로 간다.
 * 이름표(label)를 주면 정식 실행에서는 그 번호의 값으로 만든다.
 */
export async function goToMain(label?: string): Promise<Person> {
  return step("common", "goToMain", async () => {
    await openApp();
    const who = await createAccountWithApi(runUser(label, "A"));
    await signIn(who.user);
    await expectScreen("home");
    return who;
  });
}
