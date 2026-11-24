import { browser, driver } from "@wdio/globals";

/** 바닥 도구: 키보드가 열려 있으면 닫는다. 열린 키보드에 가려진 것은 화면 구조에서 사라진다 */
export const closeKeyboard = async () => {
  if (!(await driver.isKeyboardShown())) return;
  await driver.execute("mobile: pressKey", { keycode: 4 }); // 뒤로 (키보드가 열려 있을 때만 누르므로 화면은 그대로다)
  await browser.waitUntil(async () => !(await driver.isKeyboardShown()));
};
