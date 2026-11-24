import { $, $$, browser, expect } from "@wdio/globals";
import { buttonOf, byId, inputOf } from "./find";
import { scrollTo } from "./scroll-to";

/** 바닥 판정: 버튼이 켜져 있다 (안쪽 버튼을 읽는다) */
export const expectEnabledOnScreen = async (id: string) => {
  await scrollTo(id);
  await expect(buttonOf(id)).toBeEnabled();
};

/** 바닥 판정: 버튼이 꺼져 있다 (안쪽 버튼을 읽는다. 바깥은 언제나 켜진 것으로 보인다) */
export const expectDisabledOnScreen = async (id: string) => {
  await scrollTo(id);
  await expect(buttonOf(id)).toBeDisabled();
};

/** 바닥 판정: 어떤 줄(outer) 안의 버튼이 꺼져 있다. 줄이 보이는 자리에서 부른다 */
export const expectDisabledInsideOnScreen = (outer: string, id: string) =>
  expect(
    $(`//*[@resource-id="${outer}"]//*[@resource-id="${id}"]//android.widget.Button`)
  ).toBeDisabled();

/**
 * 바닥 판정: 이 글자로 시작하는 식별자를 가진 줄이 정확히 count개 보인다.
 * 화면에 다 들어오는 짧은 목록에만 쓴다 (긴 목록은 보이는 줄만 있다).
 */
export const expectRowCountOnScreen = (prefix: string, count: number) =>
  browser.waitUntil(
    async () => (await $$(`//*[starts-with(@resource-id,"${prefix}")]`).length) === count,
    { timeoutMsg: `줄의 개수가 ${count}이 아닙니다: ${prefix}` }
  );

/** 바닥 판정: 글자가 정확히 이것이다. Flutter의 글자는 content-desc 에 있다 */
export const expectTextOnScreen = (id: string, text: string) =>
  expect(byId(id)).toHaveAttribute("content-desc", text);

/** 바닥 판정: 입력 칸에 든 글자가 정확히 이것이다 */
export const expectTypedOnScreen = (id: string, text: string) =>
  browser.waitUntil(async () => (await inputOf(id).getText()) === text, {
    timeoutMsg: `칸의 글자가 다릅니다: ${id}`,
  });

/** 바닥 판정: 이 안 어딘가에 이 글자가 보인다 (이름 없는 안내 글에 쓴다) */
export const expectTextInsideOnScreen = (id: string, text: string) =>
  expect(
    $(`(//*[@resource-id="${id}"]/descendant-or-self::*[contains(@content-desc,"${text}")])[1]`)
  ).toBeDisplayed();

/**
 * 바닥 판정: 화면 구조에 없다 (사라질 때까지 기다린다).
 * not.toBeDisplayed() 는 쓰지 않는다: 요소가 사라지는 순간에 걸리면 20초 넘게 헛기다린다.
 */
export const expectHiddenOnScreen = (id: string) =>
  browser.waitUntil(async () => !(await byId(id).isExisting()), {
    timeoutMsg: `아직 보입니다: ${id}`,
  });
