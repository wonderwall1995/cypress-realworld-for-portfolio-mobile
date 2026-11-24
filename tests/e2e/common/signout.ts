import { step } from "../fixture/step";
import { expectScreen } from "./screen/expect-screen";
import { tap } from "./screen/tap";

/** 공통 코드: 더보기 메뉴에서 로그아웃을 누른다. 로그인 화면으로 돌아오는 것으로 동작이 됐는지 확인한다. */
export async function signOut() {
  return step("common", "signOut", async () => {
    await tap("sidenav-more");
    await tap("sidenav-signout");
    await expectScreen("signin");
  });
}
