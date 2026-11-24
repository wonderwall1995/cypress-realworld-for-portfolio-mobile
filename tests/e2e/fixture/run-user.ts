import { randomUser, RandomUser } from "./random-user";
import { fixtureValue, runFixtures } from "./run-fixtures";

/**
 * Fixture 코드: 이 사람이 가입에 쓸 값. 정식 실행이면 이름표의 번호 값, 아니면 무작위다.
 * 이름표가 없는 시험(label 없음)은 언제나 무작위다.
 */
export const runUser = (label: string | undefined, name: string): RandomUser => {
  const fixtures = label ? runFixtures(label) : undefined;
  if (!fixtures) return randomUser();
  const of = (item: string) => fixtureValue(fixtures, `${name}.${item}`);
  return {
    firstName: of("firstName"),
    lastName: of("lastName"),
    username: of("username"),
    phoneNumber: of("phoneNumber"),
    password: of("password"),
  };
};
