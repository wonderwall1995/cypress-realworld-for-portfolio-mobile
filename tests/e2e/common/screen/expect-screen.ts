import { $ } from "@wdio/globals";
import { byId } from "./find";

// 화면마다 대표 하나. 그 화면에만 있고, 스크롤해도 사라지지 않는 것이다 (웹의 toHaveURL 자리)
const SCREENS = {
  signin: () => $('(//*[starts-with(@resource-id,"signin-")])[1]'),
  signup: () => $('(//*[starts-with(@resource-id,"signup-")])[1]'), // 긴 폼이라 어느 칸 하나로는 안 된다
  home: () => byId("nav-transaction-tabs"),
  myAccount: () => byId("sidenav-user-balance"),
  bankAccounts: () => byId("bankaccount-new"),
} as const;

/** 바닥 판정: 지금 이 화면이다 */
export const expectScreen = async (name: keyof typeof SCREENS) => {
  await SCREENS[name]().waitForDisplayed({ timeoutMsg: `이 화면이 아닙니다: ${name}` });
};
