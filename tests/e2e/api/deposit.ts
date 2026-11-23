import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/**
 * API 도구: 이 사람의 은행 계좌에 입금한다 (POST /api/bankTransfers, 달러, 정수).
 * 동작이 됐는지만 확인한다: 입금되지 않으면(201이 아니면) 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function depositWithApi(who: Person, accountId: string, dollars: number) {
  return step("api", "depositWithApi", async () => {
    const response = await who.api.post("/api/bankTransfers", {
      data: { bankAccountId: accountId, amount: dollars, type: "deposit" },
    });
    expect(response.status()).toBe(201);
  });
}
