import { step } from "../fixture/step";
import { expectHiddenOnScreen } from "./screen/expect-control";
import { byId } from "./screen/find";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/**
 * 공통 코드: 내 계좌 탭에서 입금 창을 열고 계좌 하나를 고른다.
 * 입금 창은 열려 있는 채로 남는다. (금액을 쓰는 것은 부른 쪽의 일이다)
 */
export async function openDeposit(accountId: string) {
  return step("common", "openDeposit", async () => {
    await tap("sidenav-my-account");
    await tap("sidenav-deposit");
    await byId("deposit-dialog").waitForDisplayed();
    await tap(`deposit-account-${accountId}`);
  });
}

/**
 * 공통 코드: 계좌 하나를 골라 입금한다 (금액은 달러, 정수).
 * 입금이 성공해야 창이 닫히므로, 창이 닫히는 것으로 성공을 판정한다.
 */
export async function deposit(accountId: string, dollars: number) {
  return step("common", "deposit", async () => {
    await openDeposit(accountId);
    await typeInto("deposit-amount-input", String(dollars));
    await tap("deposit-submit-button");
    await expectHiddenOnScreen("deposit-dialog");
  });
}
