import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** DB에 있는 은행 계좌 행 수. 숨긴 행(앱의 삭제)도 센다. */
export interface BankAccountRows {
  total: number; // DB의 모든 행
  visible: number; // 앱에 보이는 행
  hidden: number; // 앱이 숨기기만 한 행 (soft delete)
}

/**
 * API 도구: 이 사람의 은행 계좌 행 수를 센다 (GET /api/demo/bankaccounts/count).
 * 앱의 삭제는 지우는 것이 아니라 숨기는 것이라, 삭제한 계좌가 DB에 남아 있는지(hidden)를 이 도구로 확인한다.
 * 이 사람의 API 로그인으로 부른다(화면의 로그인과 별개다). 응답이 성공이 아니면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getBankAccountRowsWithApi(who: Person): Promise<BankAccountRows> {
  return step("api", "getBankAccountRowsWithApi", async () => {
    const response = await who.api.get("/api/demo/bankaccounts/count");
    expect(response.ok()).toBeTruthy();
    return response.json();
  });
}
