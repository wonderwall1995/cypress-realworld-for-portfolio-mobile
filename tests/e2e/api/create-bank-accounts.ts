import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import { randomBankAccountInput } from "../fixture/random-bank-account";
import { getBankAccountsWithApi } from "./get-bank-accounts";
import type { Person } from "./person";

/**
 * API 도구: 은행 계좌가 모두 total개가 될 때까지, 모자란 만큼 한꺼번에 만든다 (POST /api/bankAccounts).
 * 이 사람의 API 로그인으로 부른다(화면의 로그인과 별개다).
 * 은행 이름은 "테스트 은행 NN" (NN은 몇 번째 계좌인지: 01, 02, ... 60), 계좌 번호는 무작위다.
 * 하나라도 만들어지지 않으면(200이 아니면) 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function createBankAccountsWithApi(who: Person, total: number) {
  return step("api", "createBankAccountsWithApi", async () => {
    const accounts = await getBankAccountsWithApi(who);
    for (let count = accounts.length; count < total; count += 1) {
      const number = String(count + 1).padStart(2, "0");
      const response = await who.api.post("/api/bankAccounts", {
        data: { bankName: `테스트 은행 ${number}`, accountNumber: randomBankAccountInput().accountNumber },
      });
      expect(response.status()).toBe(200);
    }
  });
}
