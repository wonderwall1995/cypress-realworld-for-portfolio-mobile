import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** 서버가 알려 주는 좋아요 하나 */
export interface LikeInfo {
  id: string;
  userId: string;
  transactionId: string;
}

/**
 * API 도구: 거래 하나의 좋아요 목록을 서버에서 읽어 돌려준다 (GET /api/likes/:transactionId).
 * 이 사람이 볼 수 있는 거래여야 한다. 읽기가 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getLikesWithApi(who: Person, transactionId: string): Promise<LikeInfo[]> {
  return step("api", "getLikesWithApi", async () => {
    const response = await who.api.get(`/api/likes/${transactionId}`);
    expect(response.ok()).toBeTruthy();
    return (await response.json()).likes;
  });
}
