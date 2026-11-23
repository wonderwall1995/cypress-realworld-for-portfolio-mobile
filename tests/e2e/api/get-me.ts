import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** 서버가 알려 주는 내 정보. 비운 이메일과 전화번호는 null 이다 */
export interface Me {
  id: string;
  username: string;
  lastName: string;
  firstName: string;
  email: string | null;
  phoneNumber: string | null;
}

/**
 * API 도구: 이 사람의 정보를 서버에서 읽어 돌려준다 (GET /api/checkAuth).
 * 읽기가 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getMeWithApi(who: Person): Promise<Me> {
  return step("api", "getMeWithApi", async () => {
    const response = await who.api.get("/api/checkAuth");
    expect(response.ok()).toBeTruthy();
    return (await response.json()).user;
  });
}
