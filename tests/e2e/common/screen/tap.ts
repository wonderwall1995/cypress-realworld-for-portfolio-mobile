import { closeKeyboard } from "./keyboard";
import { byId } from "./find";
import { scrollTo } from "./scroll-to";

/** 바닥 도구: 이 식별자를 누른다. 키보드를 닫고, 보일 때까지 밀고, 누른다 */
export const tap = async (id: string) => {
  await closeKeyboard();
  await scrollTo(id);
  await byId(id).click();
};
