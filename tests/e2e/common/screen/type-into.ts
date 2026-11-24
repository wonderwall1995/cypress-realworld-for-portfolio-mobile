import { browser, expect } from "@wdio/globals";
import { closeKeyboard } from "./keyboard";
import { inputOf } from "./find";
import { scrollTo } from "./scroll-to";

/**
 * 바닥 도구: 입력 칸을 비우고 값을 쓴다.
 * 누르고, 포커스를 기다리고, 쓴다. 포커스 없이 쓰면 화면 구조에는 글자가 보이지만 앱은 받지 못한다(거짓 통과).
 * 글자 수로 확인한다: 비밀번호 칸은 점으로 보이기 때문이다. 앱이 정말 받았는지는 다음 화면과 서버가 말해 준다.
 */
export const typeInto = async (id: string, value: string) => {
  await closeKeyboard();
  await scrollTo(id);
  const input = inputOf(id);
  await input.click();
  await browser.waitUntil(async () => (await input.getAttribute("focused")) === "true", {
    timeoutMsg: `포커스가 오지 않았습니다: ${id}`,
  });
  await input.setValue(value);
  expect((await input.getText()).length).toBe(value.length);
  await closeKeyboard();
};
