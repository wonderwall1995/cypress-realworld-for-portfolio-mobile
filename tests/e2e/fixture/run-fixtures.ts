/**
 * Fixture 코드: 정식 실행에서 시작 단계(wdio.conf.ts 의 onPrepare)가 서버에서 받아 온 값을 꺼낸다.
 * 번호 없이 도는 실행(파일 하나만 돌리기)에는 값이 없다(undefined). 그때는 부른 쪽이 무작위 값을 쓴다.
 * 시작 단계가 받은 값을 환경 값 TEST_RUN_FIXTURES 로 넣어 준다.
 */

/** 이름표 하나의 값들. 예: { "A.username": "...", cycleDollars: "217" } */
export type LabelFixtures = Record<string, string>;

/** 정식 실행이면 이 이름표(예: "transfer")의 값, 아니면 undefined */
export const runFixtures = (label: string): LabelFixtures | undefined => {
  const text = process.env.TEST_RUN_FIXTURES;
  if (!text) return undefined;
  const fixtures = JSON.parse(text)[label] as LabelFixtures | undefined;
  if (!fixtures) throw new Error(`Fixture 규칙 목록에 없는 이름표입니다: ${label}`);
  return fixtures;
};

/** 값 하나를 꺼낸다. 없는 항목이면 이름을 잘못 쓴 것이므로 분명한 오류를 낸다. */
export const fixtureValue = (fixtures: LabelFixtures, item: string): string => {
  const value = fixtures[item];
  if (value === undefined) throw new Error(`Fixture에 없는 항목입니다: ${item}`);
  return value;
};
