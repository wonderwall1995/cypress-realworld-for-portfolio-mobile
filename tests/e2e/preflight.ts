// 시험을 시작하기 전에 준비가 됐는지 본다 (pnpm test 가 맨 먼저 부른다). 빠진 것을 한꺼번에 알려 주고, 하나라도 빠지면 시작하지 않는다.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const APP = "io.github.wonderwall1995.cypress_realworld_for_personal_portfolio_mobile";
const ENV = join(import.meta.dirname, ".env");
if (existsSync(ENV)) process.loadEnvFile(ENV);

const adb = (...args: string[]) => {
  const run = spawnSync("adb", args, { encoding: "utf8", timeout: 15_000 });
  return run.status === 0 ? run.stdout : "";
};
const problems: string[] = [];

// 1) 값
if (!existsSync(ENV)) problems.push("tests/e2e/.env 가 없습니다. 같은 자리의 .env.example 을 복사해 채우세요.");

// 2) 서버: 로그인하지 않았으니 401이면 켜져 있는 것이다
const api = process.env.E2E_API_URL ?? "http://127.0.0.1:7202";
const status = await fetch(`${api}/api/checkAuth`, { signal: AbortSignal.timeout(5_000) })
  .then((answer) => answer.status)
  .catch(() => 0);
if (status !== 401) {
  problems.push(`서버가 답하지 않습니다 (${status === 0 ? "연결 안 됨" : `응답 ${status}`}). 웹 저장소의 Docker를 켜세요.`);
}

// 3) DB: 읽기 전용 사용자로 읽히는지
try {
  const { closeDb, db } = await import("./db/client");
  await db().user.count();
  await closeDb();
} catch (error) {
  const text = error instanceof Error ? error.message : String(error);
  problems.push(
    /did not initialize|@prisma\/client/.test(text)
      ? "Prisma client가 없습니다. pnpm test:generate 를 한 번 돌리세요."
      : "DB를 읽지 못했습니다. DB가 켜져 있는지, 읽기 전용 사용자가 있는지 보세요 (tests/e2e/README.md 4번)."
  );
}

// 4) 기기와 앱
const devices = adb("devices").split("\n").filter((line) => /\tdevice\s*$/.test(line));
if (devices.length === 0) {
  problems.push("켜진 에뮬레이터가 없습니다. pnpm device:start 를 돌리세요.");
} else if (devices.length > 1) {
  problems.push(`기기가 ${devices.length}대입니다. 하나만 켜 두세요.`);
} else if (adb("shell", "getprop", "sys.boot_completed").trim() !== "1") {
  problems.push("에뮬레이터가 아직 켜지는 중입니다. 잠시 뒤 다시 하세요.");
} else if (!adb("shell", "pm", "list", "packages", APP).includes(APP)) {
  problems.push("앱이 깔려 있지 않습니다. pnpm build 와 pnpm start 를 돌리세요.");
}

if (problems.length > 0) {
  console.error(`\n시험을 시작하지 않았습니다. 준비할 것 ${problems.length}가지:\n`);
  for (const problem of problems) console.error(`  - ${problem}`);
  console.error("");
  process.exitCode = 1;
} else {
  console.log("준비됨: 서버, DB, 에뮬레이터, 앱");
}
