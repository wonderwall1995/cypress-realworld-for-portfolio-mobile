import { step } from "../fixture/step";
import { fixtureValue, LabelFixtures, runFixtures } from "../fixture/run-fixtures";
import { runUser } from "../fixture/run-user";
import { createFundedUserWithApi, FundedUser, FundedUserInput } from "./create-funded-user";

// 이름표의 값에서 한 사람을 만들 값을 꺼낸다
const inputOf = (label: string, fixtures: LabelFixtures, name: string): FundedUserInput => {
  const of = (item: string) => fixtureValue(fixtures, `${name}.${item}`);
  return {
    user: runUser(label, name),
    account: { bankName: of("bankName"), accountNumber: of("accountNumber") },
  };
};

/**
 * API 도구: 여러 사람을 이름 붙은 묶음으로 한 번에 준비한다. 각자 은행 계좌 하나와 그 안의 돈(달러, 정수)을 가진다.
 * 예: createUsersWithApi(["A", "B", "C"], 1000, "transfer") -> { A, B, C }
 * 이름표(label)를 주면 정식 실행에서는 그 번호의 Fixture 값으로 만든다. 번호 없는 실행이나 이름표가 없으면 무작위다.
 * 순서는 상관없다: 사람마다 API 로그인이 따로라서, 나중에 만든 사람이 앞 사람의 로그인을 바꾸지 않는다.
 */
export async function createUsersWithApi<Name extends string>(
  names: readonly Name[],
  dollars: number,
  label?: string
): Promise<Record<Name, FundedUser>> {
  return step("api", "createUsersWithApi", async () => {
    const fixtures = label ? runFixtures(label) : undefined;
    const users = {} as Record<Name, FundedUser>;
    for (const name of names) {
      const input = label && fixtures ? inputOf(label, fixtures, name) : undefined;
      users[name] = await createFundedUserWithApi(dollars, input);
    }
    return users;
  });
}
