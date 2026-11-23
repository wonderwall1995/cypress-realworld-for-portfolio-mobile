import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/** 거래 목록의 한 줄 (이 시험들이 쓰는 값만) */
export interface TransactionInfo {
  id: string;
  amount: number; // 센트
  senderId: string;
  receiverId: string;
  createdAt: string;
}

/** 거래 목록의 필터. 금액은 센트, 날짜는 ISO 글자다 */
export type TransactionFilter = Partial<
  Record<
    | "depositMin"
    | "depositMax"
    | "withdrawalMin"
    | "withdrawalMax"
    | "dateRangeStart"
    | "dateRangeEnd",
    string | number
  >
>;

/** 거래 목록을 묻는 주소. 경계값과 거절의 표는 웹이 맡는다 */
export const myTransactionsUrl = (filter: TransactionFilter = {}) => {
  const query = new URLSearchParams({ page: "1", limit: "10" });
  for (const [key, value] of Object.entries(filter)) query.set(key, String(value));
  return `/api/transactions?${query}`;
};

/**
 * API 도구: 이 사람의 거래 목록을 필터를 걸어 읽어 돌려준다 (GET /api/transactions, 첫 10건).
 * 읽기가 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function getMyTransactionsWithApi(
  who: Person,
  filter: TransactionFilter = {}
): Promise<TransactionInfo[]> {
  return step("api", "getMyTransactionsWithApi", async () => {
    const response = await who.api.get(myTransactionsUrl(filter));
    expect(response.status()).toBe(200);
    return (await response.json()).results;
  });
}
