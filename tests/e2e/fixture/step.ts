import { basename } from "node:path";

/** 도구 하나의 결과. 정식 실행이면 시험의 결과와 함께 서버로 간다 (app_test_record 의 종류와 같은 이름을 쓴다) */
export interface StepRecord {
  kind: "common" | "api" | "fixture";
  name: string;
  file: string; // 도구가 있는 파일
  status: "passed" | "failed";
  depth: number; // 다른 도구 안에서 불렸으면 1 이상
  startedAt: number;
  durationMs: number;
  errorMessage?: string;
}

// wdio.conf.ts 와 spec 은 이 파일을 따로 불러온다. 그래서 기록을 한곳(globalThis)에 둔다
const shared = globalThis as typeof globalThis & { e2eSteps?: StepRecord[] };
const records = (shared.e2eSteps ??= []);
let depth = 0;

// 이 도구가 있는 파일 이름: step 을 부른 첫 파일
const callerFile = () => {
  for (const line of (new Error().stack ?? "").split("\n").slice(1)) {
    const file = /([^/\\()]+\.ts)(\?[^:]*)?:\d+:\d+/.exec(line)?.[1];
    if (file && file !== "step.ts") return basename(file);
  }
  return "unknown";
};

/**
 * Fixture 코드: 도구의 몸체를 감싼다 (웹의 test.step 자리). 결과와 걸린 시간을 적고, 오류는 그대로 다시 던진다.
 * DB 도구는 종류를 api 로 적는다.
 */
export const step = async <T>(
  kind: StepRecord["kind"],
  name: string,
  body: () => Promise<T>
): Promise<T> => {
  const startedAt = Date.now();
  const file = callerFile();
  const mine = depth;
  depth += 1;
  let status: StepRecord["status"] = "failed";
  let errorMessage: string | undefined;
  try {
    const value = await body();
    status = "passed";
    return value;
  } catch (error) {
    errorMessage = error instanceof Error ? error.message : String(error);
    throw error;
  } finally {
    depth -= 1;
    const durationMs = Date.now() - startedAt;
    records.push({ kind, name, file, status, depth: mine, startedAt, durationMs, errorMessage });
  }
};

/** 지금까지 적은 것을 꺼내고 비운다. 테스트 하나가 끝날 때마다 부른다 */
export const takeStepRecords = (): StepRecord[] => records.splice(0);
