import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import { randomBankAccountInput } from "../fixture/random-bank-account";
import { RandomUser } from "../fixture/random-user";
import { createAccountWithApi } from "./create-account";
import type { Person } from "./person";

/** 돈이 든 은행 계좌 하나를 가진 사람 */
export interface FundedUser extends Person {
  account: { id: string; bankName: string; accountNumber: string };
}

/** 사용자와 은행 계좌를 만들 값. 주지 않으면 무작위로 만든다 */
export interface FundedUserInput {
  user: RandomUser;
  account: { bankName: string; accountNumber: string };
}

/**
 * API 도구: 사용자 한 명을 통째로 준비한다. 가입 -> 로그인 -> 은행 계좌 만들기 -> 그 계좌에 입금(달러, 정수).
 * 만든 사람과 계좌를 돌려준다 ({ user, api, account }). 값(input)을 주면 그 값으로 만들고, 없으면 무작위다.
 * 동작이 됐는지만 확인한다: 가입, 로그인, 계좌, 입금 중 하나라도 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function createFundedUserWithApi(
  dollars: number,
  input?: FundedUserInput
): Promise<FundedUser> {
  return step("api", "createFundedUserWithApi", async () => {
    const who = await createAccountWithApi(input?.user);

    const account = input?.account ?? randomBankAccountInput();
    const created = await who.api.post("/api/bankAccounts", { data: account });
    expect(created.status()).toBe(200);
    const accountId: string = (await created.json()).account.id;

    const deposit = await who.api.post("/api/bankTransfers", {
      data: { bankAccountId: accountId, amount: dollars, type: "deposit" },
    });
    expect(deposit.status()).toBe(201);

    return { ...who, account: { id: accountId, ...account } };
  });
}
