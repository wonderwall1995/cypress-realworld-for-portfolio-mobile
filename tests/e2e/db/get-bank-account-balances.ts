import type { Person } from "../api/person";
import { step } from "../fixture/step";
import { db } from "./client";

/** DB 도구: 이 사람의 은행 계좌 행(숨긴 행 포함)의 금액(센트)을 계좌 id 별로 돌려준다 */
export async function getBankAccountBalancesInDb(who: Person): Promise<Record<string, number>> {
  return step("api", "getBankAccountBalancesInDb", async () => {
    const rows = await db().bankAccount.findMany({ where: { userId: who.user.id } });
    return Object.fromEntries(rows.map((row) => [row.id, row.balance]));
  });
}
