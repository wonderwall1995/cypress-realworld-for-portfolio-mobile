import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** 은행 계좌 한 개 (API가 주는 값 중 시험에 쓰는 것). balance는 센트 단위다. */
export interface BankAccountInfo {
  id: string;
  bankName: string;
  accountNumber: string;
  balance: number;
}

/**
 * API 도구: 이 사람의 은행 계좌를 모두 가져온다 (GET /api/bankAccounts).
 * 이 사람의 API 로그인으로 부른다(화면의 로그인과 별개다).
 * 응답이 성공이 아니면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getBankAccountsWithApi(who: Person): Promise<BankAccountInfo[]> {
  return step("api", "getBankAccountsWithApi", async () => {
    const response = await who.api.get("/api/bankAccounts");
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    return body.results;
  });
}
