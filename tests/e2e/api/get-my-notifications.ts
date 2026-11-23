import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** 알림 하나 (이 시험들이 쓰는 값만). 이체는 status, 좋아요는 likeId, 댓글은 commentId 가 있다 */
export interface NotificationInfo {
  id: string;
  transactionId: string;
  userFullName: string; // 알림을 일으킨 사람 (성 이름)
  isRead: boolean;
  status?: string;
  likeId?: string;
  commentId?: string;
}

/**
 * API 도구: 이 사람의 읽지 않은 알림을 새것부터 읽어 돌려준다 (GET /api/notifications).
 * include 에 "read" 를 주면 읽은 알림도 함께 온다. 화면의 알림 목록이 읽는 것과 같다.
 * 읽기가 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getMyNotificationsWithApi(
  who: Person,
  include?: "read"
): Promise<NotificationInfo[]> {
  return step("api", "getMyNotificationsWithApi", async () => {
    const response = await who.api.get(
      include ? `/api/notifications?include=${include}` : "/api/notifications"
    );
    expect(response.status()).toBe(200);
    return (await response.json()).results;
  });
}
