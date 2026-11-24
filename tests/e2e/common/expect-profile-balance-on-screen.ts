import { step } from "../fixture/step";
import { moneyText } from "./money-text";
import { expectTextOnScreen } from "./screen/expect-control";
import { tap } from "./screen/tap";

/**
 * 공통 코드: 내 계좌 탭에 프로필 잔액이 기대한 금액(센트)으로 표시되는지 확인한다. 탭을 누르면 앱이 잔액을 다시 읽는다.
 * 글자 전체가 같아야 통과한다($12 를 기대할 때 $120 은 통과하지 않는다).
 */
export async function expectProfileBalanceOnScreen(cents: number) {
  return step("common", "expectProfileBalanceOnScreen", async () => {
    await tap("sidenav-my-account");
    await expectTextOnScreen("sidenav-user-balance", moneyText(cents));
  });
}
