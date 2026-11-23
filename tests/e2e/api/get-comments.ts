import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** 서버가 알려 주는 댓글 하나 */
export interface CommentInfo {
  id: string;
  userId: string;
  transactionId: string;
  content: string;
}

/**
 * API 도구: 거래 하나의 댓글 목록을 서버에서 읽어 돌려준다 (GET /api/comments/:transactionId).
 * 이 사람이 볼 수 있는 거래여야 한다. 읽기가 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getCommentsWithApi(
  who: Person,
  transactionId: string
): Promise<CommentInfo[]> {
  return step("api", "getCommentsWithApi", async () => {
    const response = await who.api.get(`/api/comments/${transactionId}`);
    expect(response.ok()).toBeTruthy();
    return (await response.json()).comments;
  });
}
