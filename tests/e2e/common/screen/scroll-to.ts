import { driver } from "@wdio/globals";
import { byId } from "./find";

const SWIPES = 40; // 한 방향으로 이만큼 밀어 본다 (계좌 60개의 끝까지 간다)

const swipe = async (direction: "down" | "up") => {
  const { width, height } = await driver.getWindowSize();
  await driver.execute("mobile: scrollGesture", {
    left: Math.round(width * 0.1),
    top: Math.round(height * 0.4), // 홈의 고정된 필터 아래에서 시작한다 (그 위에서 시작하면 목록이 움직이지 않는다)
    width: Math.round(width * 0.8),
    height: Math.round(height * 0.4),
    direction,
    percent: 1,
  });
};

/**
 * 바닥 도구: 이 식별자가 화면에 보일 때까지 아래로, 없으면 위로 민다. 끝까지 없으면 오류다.
 * 목록에는 화면 가까이에 있는 줄만 있으므로, 누르거나 쓰기 전에 부른다.
 * 끝은 밀기 전후의 화면 구조가 두 번 잇달아 같은 것으로 안다. scrollGesture 가 주는 "더 밀 수 있음" 값은 믿지 않는다
 * (중간에서도 "더 없음"이라고 한 적이 있다).
 */
export const scrollTo = async (id: string) => {
  if (await byId(id).waitForDisplayed({ timeout: 3_000 }).catch(() => false)) return;
  for (const direction of ["down", "up"] as const) {
    let before = await driver.getPageSource();
    let same = 0;
    for (let n = 0; n < SWIPES && same < 2; n += 1) {
      await swipe(direction);
      const after = await driver.getPageSource();
      if (after.includes(`resource-id="${id}"`) && (await byId(id).isDisplayed())) return;
      same = after === before ? same + 1 : 0;
      before = after;
    }
  }
  throw new Error(`화면에서 찾지 못했습니다: ${id}`);
};
