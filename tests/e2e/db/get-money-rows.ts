import type { Person } from "../api/person";
import { step } from "../fixture/step";
import { db } from "./client";

/** 이 사람의 돈에 관한 행 수. 거절된 요청은 이 수를 바꾸지 않아야 한다 */
export interface MoneyRows {
  transactions: number; // 보냈거나 받은 거래
  bankTransfers: number; // 입금과 출금
}

/**
 * DB 도구: 이 사람의 거래 행과 입출금 행을 센다.
 * 거절된 돈 요청이 행을 남기지 않았는지 본다. 잔액은 그대로여도 잘못된 행이 남을 수 있고, 화면과 API만으로는 놓칠 수 있다.
 */
export async function getMoneyRowsInDb(who: Person): Promise<MoneyRows> {
  return step("api", "getMoneyRowsInDb", async () => {
    const id = who.user.id;
    const transactions = await db().transaction.count({
      where: { OR: [{ senderId: id }, { receiverId: id }] },
    });
    const bankTransfers = await db().bankTransfer.count({ where: { userId: id } });
    return { transactions, bankTransfers };
  });
}
