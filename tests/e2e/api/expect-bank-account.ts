import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/**
 * API 도구: 화면으로 만든 은행 계좌가 실제로 있고, 금액이 0인지 확인한다 (GET /api/bankAccounts).
 * 계좌 번호로 계좌를 찾는다. 없거나 금액이 0이 아니면 이 도구를 부른 줄에서 테스트가 멈춘다.
 * 찾은 계좌(id 포함)를 돌려준다.
 */
export async function expectNewBankAccountWithApi(who: Person, account: { bankName: string; accountNumber: string }) {
  return step("api", "expectNewBankAccountWithApi", async () => {
    const response = await who.api.get("/api/bankAccounts");
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    const found = body.results.find((item: { accountNumber: string }) => item.accountNumber === account.accountNumber);
    expect(found !== undefined).toBe(true);
    expect(found.bankName).toBe(account.bankName);
    expect(found.balance).toBe(0);
    return found as { id: string; bankName: string; accountNumber: string; balance: number };
  });
}
