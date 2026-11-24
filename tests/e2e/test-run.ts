// 정식 실행 (pnpm test:run): 번호 서버에서 실행 번호와 값을 받아 시험 전부를 돌리고, 끝나면 알린다.
// 웹의 starter.spec.ts, finisher.spec.ts, test-run-reporter.ts 의 자리다. 규칙은 웹 저장소의 docs/fixture-prisma-guide.md 를 따른다.
// - 전체만 돌린다. 일부만 돌리려면 pnpm test --spec 003 을 쓴다 (번호를 받지 않는다).
// - 실패한 시험이 있어도 끝까지 돌았으면 finish 다. 중간에 멈추면 block 이다 (그 번호는 무효가 된다).
// - 신호는 시험이 하나 끝날 때마다 wdio.conf.ts 가 보낸다 (10분 동안 없으면 서버가 block 으로 바꾼다).
import { spawn, spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const HERE = import.meta.dirname;
const ROOT = join(HERE, "..", "..");
if (existsSync(join(HERE, ".env"))) process.loadEnvFile(join(HERE, ".env"));

const SERVER = process.env.TEST_RUN_SERVER ?? process.env.E2E_API_URL ?? "http://127.0.0.1:7202";
const SECRET = process.env.TEST_RUN_SECRET ?? "";
const DONE_FILE = join(tmpdir(), `e2e-run-${process.pid}.txt`); // 끝난 시험을 한 줄씩 적는 곳

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

// 시험마다 쓰는 이름표. 서버에 없는 이름표가 있으면 번호를 열지 않는다
const specs = readdirSync(HERE).filter((file) => /^\d{3}-.*\.spec\.ts$/.test(file));
const labels = specs.map((file) => /const LABEL = "([^"]+)"/.exec(readFileSync(join(HERE, file), "utf8"))?.[1] ?? "");
const missingFrom = (fixtures: object) => labels.filter((label) => !(label in fixtures));

const list = await ask("");
if (!list) stop("번호 서버에 닿지 않습니다.");
if (list!.status === 404) stop("번호 서버의 기능이 닫혀 있습니다 (비밀 값이 없거나 prisma generate 가 필요합니다).");
if (list!.status === 401) stop("TEST_RUN_SECRET 이 번호 서버의 값과 다릅니다.");
if (list!.status !== 200) stop(`번호 서버의 답이 이상합니다 (${list!.status}).`);
const latest = await (await ask("/latest"))?.json();
if (latest?.runNo && missingFrom(latest.fixtures).length > 0) {
  stop(`번호 서버에 없는 이름표: ${missingFrom(latest.fixtures).join(", ")}. 웹 저장소의 test-fixture-rules.ts 에 더해야 합니다.`);
}

for (const [command, ...args] of [
  ["node", join(HERE, "check-header.mjs")],
  ["npx", "tsx", join(HERE, "preflight.ts")],
]) {
  if (spawnSync(command, args, { cwd: ROOT, stdio: "inherit", shell: command === "npx" }).status !== 0) process.exit(1);
}

// 번호를 열거나 합류한다
const started = await ask("", { platform: "app", device: "android-emulator" });
if (!started || ![200, 201].includes(started.status)) stop(`번호를 받지 못했습니다 (${started?.status ?? "연결 안 됨"}).`);
const run: { runNo: number; opened: boolean; fixtures: Record<string, Record<string, string>> } = await started!.json();
console.log(`실행 번호 ${run.runNo} (${run.opened ? "새로 열었음" : "합류했음"})`);

const tell = async (event: "finish" | "block") => {
  const answer = await ask(`/${run.runNo}/${event}`, { platform: "app" });
  console.log(
    answer?.ok
      ? `실행 번호 ${run.runNo}: ${event === "finish" ? "끝까지 돌았음" : "중간에 멈춤 (block)"}`
      : `실행 번호 ${run.runNo}: ${event} 를 알리지 못했습니다. 서버가 10분 뒤에 block 으로 바꿉니다.`
  );
};
if (missingFrom(run.fixtures).length > 0) {
  await tell("block");
  stop(`이 번호에 없는 이름표: ${missingFrom(run.fixtures).join(", ")}`);
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
    TEST_RUN_DONE_FILE: DONE_FILE,
  },
});
let stopped = false;
for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    stopped = true;
    child.kill(signal);
  });
}
const code = await new Promise<number>((resolve) => child.on("close", (value) => resolve(value ?? 1)));

// 시험이 모두 끝까지 돌았는가 (실패도 끝까지 돈 것이다)
const done = existsSync(DONE_FILE) ? readFileSync(DONE_FILE, "utf8").trim().split("\n").length : 0;
rmSync(DONE_FILE, { force: true });
await tell(!stopped && done === specs.length ? "finish" : "block");
process.exitCode = code;
