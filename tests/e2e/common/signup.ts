import { randomUser, RandomUser } from "../fixture/random-user";
import { step } from "../fixture/step";
import { expectScreen } from "./screen/expect-screen";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/**
 * 공통 코드: 로그인 화면에서 회원가입 화면으로 가서 값을 쓰고 가입 버튼을 누른다.
 * 누르기까지만 한다: 가입이 되는지, 거절되는지는 부른 쪽이 판정한다.
 */
export async function submitSignUp(user: RandomUser) {
  return step("common", "submitSignUp", async () => {
    await tap("signup");
    await expectScreen("signup"); // 가입 화면이 열린다

    await typeInto("signup-last-name", user.lastName);
    await typeInto("signup-first-name", user.firstName);
    await typeInto("signup-username", user.username);
    await typeInto("signup-phone-number", user.phoneNumber);
    await typeInto("signup-password", user.password);
    await typeInto("signup-confirmPassword", user.password);
    await tap("signup-submit");
  });
}

/**
 * 공통 코드: 화면에서 가입한다. 가입이 끝나 로그인 화면으로 돌아오면 끝난다.
 * 값을 주면 그 값으로, 없으면 무작위로 가입한다. 비밀번호 확인 칸은 비밀번호와 같은 값이어야 한다.
 */
export async function signUp(user: RandomUser = randomUser()): Promise<RandomUser> {
  return step("common", "signUp", async () => {
    await submitSignUp(user);
    await expectScreen("signin"); // 이 확인으로 가입 요청이 끝날 때까지 기다린다
    return user;
  });
}
