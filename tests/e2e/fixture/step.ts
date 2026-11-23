/** 도구 하나의 결과. 나중에 기록기가 이것을 서버로 보낸다 (code_result 의 종류와 같은 이름을 쓴다) */
export interface StepRecord {
  kind: "common" | "api" | "fixture";
  name: string;
  status: "passed" | "failed";
  depth: number; // 다른 도구 안에서 불렸으면 1 이상
  durationMs: number;
}

// wdio.conf.ts 와 spec 은 이 파일을 따로 불러온다. 그래서 기록을 한곳(globalThis)에 둔다
const shared = globalThis as typeof globalThis & { e2eSteps?: StepRecord[] };
const records = (shared.e2eSteps ??= []);
let depth = 0;

/**
 * Fixture 코드: 도구의 몸체를 감싼다 (웹의 test.step 자리). 결과와 걸린 시간을 적고, 오류는 그대로 다시 던진다.
 * DB 도구는 종류를 api 로 적는다.
 */
export const step = async <T>(
  kind: StepRecord["kind"],
  name: string,
  body: () => Promise<T>
): Promise<T> => {
  const started = Date.now();
  const mine = depth;
  depth += 1;
  let status: StepRecord["status"] = "failed";
  try {
    const value = await body();
    status = "passed";
    return value;
  } finally {
    depth -= 1;
    records.push({ kind, name, status, depth: mine, durationMs: Date.now() - started });
  }
};

/** 지금까지 적은 것을 꺼내고 비운다. 테스트 하나가 끝날 때마다 부른다 */
export const takeStepRecords = (): StepRecord[] => records.splice(0);
