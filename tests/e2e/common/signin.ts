import { step } from "../fixture/step";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/**
 * 공통 코드: 로그인 화면에서 사용자 ID와 비밀번호를 입력하고 로그인 버튼을 누른다.
 * 누르기까지만 한다: 로그인이 되는지, 거절되는지는 부른 쪽이 판정한다.
 */
export async function signIn(user: { username: string; password: string }) {
  return step("common", "signIn", async () => {
    await typeInto("signin-username", user.username);
    await typeInto("signin-password", user.password);
    await tap("signin-submit");
  });
}
