import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/**
 * API 도구: 이 사람의 잔액(센트)을 서버에서 읽어 돌려준다 (GET /api/checkAuth).
 * 잔액은 그 사람의 보이는 은행 계좌 금액의 합이다. 다른 사람의 잔액은 서버가 알려 주지 않으므로, 그 사람을 넘긴다.
 * 읽기가 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getMyBalanceWithApi(who: Person): Promise<number> {
  return step("api", "getMyBalanceWithApi", async () => {
    const response = await who.api.get("/api/checkAuth");
    expect(response.ok()).toBeTruthy();
    return (await response.json()).user.balance as number;
  });
}
