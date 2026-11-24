import { step } from "../fixture/step";
import { byId } from "./screen/find";
import { tap } from "./screen/tap";

/** 공통 코드: 홈의 "전체" 탭을 누른다. 필터와 탭이 보이면 끝난다. */
export async function openAllTransactions() {
  return step("common", "openAllTransactions", async () => {
    await tap("sidenav-home");
    await tap("nav-public-tab");
    await byId("transaction-list-filters").waitForDisplayed();
  });
}

/** 공통 코드: 홈의 "내 거래" 탭을 누른다. 필터와 탭이 보이면 끝난다. */
export async function openMyTransactions() {
  return step("common", "openMyTransactions", async () => {
    await tap("sidenav-home");
    await tap("nav-personal-tab");
    await byId("transaction-list-filters").waitForDisplayed();
  });
}
