// 정식 실행 (pnpm test:run): 번호 서버에서 실행 번호와 값을 받아 시험 전부를 돌리고, 끝나면 알린다.
// 웹의 starter.spec.ts, finisher.spec.ts, test-run-reporter.ts 의 자리다. 규칙은 웹 저장소의 docs/fixture-prisma-guide.md 를 따른다.
// - 전체만 돌린다. 일부만 돌리려면 pnpm test --spec 003 을 쓴다 (번호를 받지 않는다).
// - 실패한 시험이 있어도 끝까지 돌았으면 finish 다. 중간에 멈추면 block 이다 (그 번호는 무효가 된다).
// - 결과는 시험이 하나 끝날 때마다 wdio.conf.ts 가 보낸다 (신호를 겸한다. 10분 동안 없으면 서버가 block 으로 바꾼다).
// - 번호를 받은 뒤에는 무엇이 잘못돼도 finish 나 block 으로 끝낸다 (열린 채 두면 웹까지 기다린다).
// - 끝나기 직전에 결과를 모두 한 번 더 보낸다. 하나라도 저장되지 않으면 finish 대신 block 이다 (빠진 결과는 믿을 수 없다).
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { keptOutcomes, sendOutcome } from "./fixture/run-results";
import { appSourceFingerprint, runCode, writtenVersion } from "./run-code";

const HERE = import.meta.dirname;
const ROOT = join(HERE, "..", "..");
if (existsSync(join(HERE, ".env"))) process.loadEnvFile(join(HERE, ".env"));

const SERVER = process.env.TEST_RUN_SERVER ?? process.env.E2E_API_URL ?? "http://127.0.0.1:7202";
const SECRET = process.env.TEST_RUN_SECRET ?? "";
const DEVICE = process.env.TEST_RUN_DEVICE || "rwa-mobile"; // 번호 서버에 남는 기기 이름
const RESULTS_FILE = join(HERE, "logs", "test-run-results.jsonl"); // 끝난 시험의 결과를 한 줄씩 적는 곳. 커밋하지 않는다

const stop = (message: string): never => {
  console.error(`\n정식 실행을 시작하지 않았습니다: ${message}\n`);
  process.exit(1);
};

const ask = async (path: string, body?: object) => {
  const answer = await fetch(`${SERVER}/api/testRuns${path}`, {
    method: body ? "POST" : "GET",
    headers: { "content-type": "application/json", authorization: `Bearer ${SECRET}` },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(15_000),
  }).catch(() => undefined);
  return answer;
};

if (process.argv.length > 2) stop("정식 실행은 언제나 전체를 돌립니다. 일부는 pnpm test --spec 003 처럼 돌리세요.");
if (SECRET.length < 32) stop("TEST_RUN_SECRET 이 없습니다. tests/e2e/.env 에 넣으세요 (웹 서버의 값과 같은 값).");

// 시험마다 쓰는 이름표. 번호에 저장된 값만 보고 미리 막지 않는다: 서버가 합류할 때 새 이름표의 값을 채워 준다
const specs = readdirSync(HERE).filter((file) => /^\d{3}-.*\.spec\.ts$/.test(file));
const labels = specs.map((file) => /const LABEL = "([^"]+)"/.exec(readFileSync(join(HERE, file), "utf8"))?.[1] ?? "");
const missingFrom = (fixtures: object) => labels.filter((label) => !(label in fixtures));

const list = await ask("");
if (!list) stop("번호 서버에 닿지 않습니다.");
if (list!.status === 404) stop("번호 서버의 기능이 닫혀 있습니다 (비밀 값이 없거나 prisma generate 가 필요합니다).");
if (list!.status === 401) stop("TEST_RUN_SECRET 이 번호 서버의 값과 다릅니다.");
if (list!.status !== 200) stop(`번호 서버의 답이 이상합니다 (${list!.status}).`);

for (const [command, ...args] of [
  ["node", join(HERE, "check-header.mjs")],
  ["npx", "tsx", join(HERE, "preflight.ts")],
]) {
  if (spawnSync(command, args, { cwd: ROOT, stdio: "inherit", shell: command === "npx" }).status !== 0) process.exit(1);
}

// 앞선 실행의 결과가 이 번호에 섞이면 안 된다
mkdirSync(join(HERE, "logs"), { recursive: true });
rmSync(RESULTS_FILE, { force: true });

// 어떤 코드로 도는지 서버에 알린다 (서버가 버전을 매긴다). 앱의 버전은 기기에 깔린 앱의 것이다
const running = runCode();
if (!running.target) console.log("깔린 앱의 버전을 알 수 없습니다 (pnpm build 로 만든 앱이 아닙니다). 빈칸으로 기록합니다.");
else if (running.target !== appSourceFingerprint()) console.log("깔린 앱이 지금의 앱 소스로 만든 것이 아닙니다. 깔린 앱의 버전으로 기록합니다.");
if (running.target && running.targetVersion !== writtenVersion()) {
  console.log(`깔린 앱의 버전(${running.targetVersion ?? "없음"})이 apps/mobile/VERSION(${writtenVersion() ?? "없음"})과 다릅니다. 깔린 앱의 버전으로 기록합니다.`);
}

// 버전과 코드가 맞지 않으면 서버가 알려 준다. 알리기만 하고 멈추지 않는다. 판단은 message 가 아니라 code 로 한다
const WARNINGS: Record<string, string> = {
  code_changed: "코드가 바뀌었는데 버전이 그대로입니다",
  version_changed: "코드는 같은데 버전이 다릅니다. 예전 버전을 씁니다",
  version_missing: "버전이 없습니다",
  fingerprint_missing: "지문이 없어 코드를 확인할 수 없습니다",
};
const showWarnings = (warnings: unknown) => {
  for (const warning of Array.isArray(warnings) ? warnings : []) {
    const { part, code, sent, used } = warning ?? {};
    console.log(`버전 경고 (${part}): ${WARNINGS[code] ?? code}. 적은 것 ${sent ?? "없음"}, 쓴 것 ${used ?? "없음"}`);
  }
};

// 번호를 열거나 합류한다
const started = await ask("", { platform: "app", device: DEVICE, code: running });
if (!started || ![200, 201].includes(started.status)) stop(`번호를 받지 못했습니다 (${started?.status ?? "연결 안 됨"}).`);
const run: {
  runNo: number;
  opened?: boolean;
  versions?: { server?: string | null; target?: string | null }; // 버전을 모르는 서버는 주지 않는다
  warnings?: unknown;
  fixtures: Record<string, Record<string, string>>;
} = await started!.json();

const tell = async (event: "finish" | "block") => {
  const answer = await ask(`/${run.runNo}/${event}`, { platform: "app" });
  console.log(
    answer?.ok
      ? `실행 번호 ${run.runNo}: ${event === "finish" ? "끝까지 돌았음" : "중간에 멈춤 (block)"}`
      : `실행 번호 ${run.runNo}: ${event} 를 알리지 못했습니다. 서버가 10분 뒤에 block 으로 바꿉니다.`
  );
  // 실행하는 동안 서버가 바뀌었으면 끝의 답에 경고가 있다
  if (answer?.ok) showWarnings((await answer.json().catch(() => undefined))?.warnings);
};
try {
  console.log(
    `실행 번호 ${run.runNo} (${run.opened ? "새로 열었음" : "합류했음"}), 기기 ${DEVICE}, 서버 ${run.versions?.server ?? "모름"}, 앱 ${run.versions?.target ?? "모름"}`
  );
  showWarnings(run.warnings);
  if (missingFrom(run.fixtures).length > 0) {
    throw new Error(`이 번호에 없는 이름표: ${missingFrom(run.fixtures).join(", ")}. 웹 저장소의 test-fixture-rules.ts 에 더해야 합니다.`);
  }

  // 시험을 돌린다. 값에는 비밀번호가 있으므로 화면에 찍지 않고 환경 값으로만 넘긴다
  const child = spawn("npx", ["wdio", "run", "wdio.conf.ts"], {
    cwd: ROOT,
    stdio: "inherit",
    shell: true,
    env: {
      ...process.env,
      TEST_RUN_FIXTURES: JSON.stringify(run.fixtures),
      TEST_RUN_NO: String(run.runNo),
      TEST_RUN_SERVER: SERVER,
      TEST_RUN_RESULTS_FILE: RESULTS_FILE,
    },
  });
  let stopped = false;
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
      stopped = true;
      child.kill(signal);
    });
  }
  const code = await new Promise<number>((resolve, reject) => {
    child.on("close", (value) => resolve(value ?? 1));
    child.on("error", reject);
  });

  // 시험이 모두 끝까지 돌았고(실패도 끝까지 돈 것이다), 결과가 모두 저장됐는가
  const outcomes = keptOutcomes(RESULTS_FILE);
  let missing = 0;
  for (const outcome of outcomes) {
    if (!(await sendOutcome(SERVER, run.runNo, outcome))) missing += 1;
  }
  console.log(`결과 ${outcomes.length}개 가운데 저장된 것 ${outcomes.length - missing}개`);
  const labelsDone = new Set(outcomes.map((outcome) => outcome.testCase));
  const complete = !stopped && missing === 0 && labels.every((label) => labelsDone.has(label));
  await tell(complete ? "finish" : "block");
  process.exitCode = complete ? code : code || 1;
} catch (error) {
  console.error(`\n정식 실행을 멈췄습니다: ${error instanceof Error ? error.message : error}\n`);
  await tell("block");
  process.exitCode = 1;
}
