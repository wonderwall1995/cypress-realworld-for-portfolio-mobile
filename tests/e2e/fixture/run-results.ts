/**
 * Fixture 코드: 정식 실행의 결과를 번호 서버로 보낸다 (웹 저장소의 docs/fixture-prisma-guide.md 3.17).
 * 결과는 먼저 파일에 적고 보낸다. 보내지 못한 것은 test-run.ts 가 끝나기 직전에 한 번 더 보낸다 (서버는 같은 결과를 한 번만 저장한다).
 * 번호 없이 도는 실행에서는 아무것도 하지 않는다 (TEST_RUN_NO 가 없다).
 */
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { basename } from "node:path";
import type { StepRecord } from "./step";

const MAX_STEPS = 300; // 서버가 받는 도구의 최대 개수
const MAX_ERROR = 300;

/** 서버가 저장하는 시험 하나의 결과 */
export interface TestOutcome {
  platform: "app";
  testCase: string;
  name: string;
  file: string;
  attempt: number;
  status: "passed" | "failed";
  startedAt: string;
  durationMs: number;
  errorMessage?: string;
  steps: object[];
}

/** 이름표는 파일 이름이다: 002-deposit.spec.ts -> deposit (웹과 같다) */
export const labelOf = (file: string) => /^\d{3}-(.+)\.spec\.ts$/.exec(basename(file))?.[1];

// 색을 나타내는 글자와 보이지 않는 글자를 빼고, 첫 줄만. DB 탭이 모든 표를 보여 주므로 길게 남기지 않는다
const shortError = (message: string | undefined) =>
  message
    ?.replace(/\p{Cc}\[[0-9;]*m/gu, "")
    .trim()
    .split("\n")[0]
    .replace(/\p{Cc}/gu, " ")
    .slice(0, MAX_ERROR) || undefined;

/** 시험 하나의 결과를 서버의 모양으로 만든다. 도구가 부른 도구도 모두 그 시험의 것이다. 번호로 시작하지 않는 파일이면 undefined */
export const outcomeOf = (
  test: { title: string; file: string },
  result: { passed: boolean; error?: { message?: string }; startedAt: number; durationMs: number },
  steps: StepRecord[]
): TestOutcome | undefined => {
  const testCase = labelOf(test.file);
  if (!testCase) return undefined;
  return {
    platform: "app",
    testCase,
    name: test.title.slice(0, 200),
    file: basename(test.file),
    attempt: 1, // 정식 실행은 다시 하지 않는다
    status: result.passed ? "passed" : "failed",
    startedAt: new Date(result.startedAt).toISOString(),
    durationMs: Math.max(0, Math.round(result.durationMs)),
    errorMessage: result.passed ? undefined : shortError(result.error?.message),
    steps: steps.slice(0, MAX_STEPS).map((item) => ({
      kind: item.kind,
      name: item.name,
      file: item.file,
      status: item.status,
      startedAt: new Date(item.startedAt).toISOString(),
      durationMs: item.durationMs,
      errorMessage: shortError(item.errorMessage),
    })),
  };
};

export const keepOutcome = (file: string, outcome: TestOutcome) =>
  appendFileSync(file, `${JSON.stringify(outcome)}\n`);

export const keptOutcomes = (file: string): TestOutcome[] =>
  existsSync(file)
    ? readFileSync(file, "utf8")
        .split("\n")
        .filter((line) => line !== "")
        .map((line) => JSON.parse(line))
    : [];

/** 보낸다. 서버가 그 결과를 가졌으면(지금 저장했거나 전에 저장했으면) true */
export const sendOutcome = async (server: string, runNo: number | string, outcome: TestOutcome) =>
  fetch(`${server}/api/testRuns/${runNo}/results`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${process.env.TEST_RUN_SECRET ?? ""}`,
    },
    body: JSON.stringify(outcome),
    signal: AbortSignal.timeout(15_000),
  })
    .then((answer) => answer.ok)
    .catch(() => false);
