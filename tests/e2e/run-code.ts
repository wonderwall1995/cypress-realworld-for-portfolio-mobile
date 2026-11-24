// 정식 실행이 어떤 코드로 도는지: 시험 코드의 커밋과, 기기에 깔린 앱의 지문.
// 앱의 지문은 앱을 만들 때(build-app.ts) 앱의 소스 파일로 계산해 Android 버전 이름 뒤에 붙인다: 1.0.0-0123456789abcdef
// 번호 서버가 지문마다 버전(0.100, 0.101 ...)을 매긴다. 커밋하지 않은 변경도 구별한다.
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export const ROOT = join(import.meta.dirname, "..", "..");
const APP = "io.github.wonderwall1995.cypress_realworld_for_personal_portfolio_mobile";
const APP_SOURCES = ["apps/mobile/lib", "apps/mobile/android", "apps/mobile/pubspec.yaml", "apps/mobile/pubspec.lock"];
// 잠금 파일도 본다: 도구의 버전이 바뀌면 같은 시험이 아니다
const TEST_SOURCES = ["tests/e2e", "wdio.conf.ts", "package.json", "pnpm-lock.yaml", "pnpm-workspace.yaml"];

const git = (...args: string[]) => execFileSync("git", args, { cwd: ROOT, encoding: "utf8", timeout: 15_000 }).trim();

/** 지금 소스 파일의 지문. git이 무시하는 파일(빌드 결과, 열쇠, .env)은 빼고, 줄 끝의 차이는 세지 않는다 */
export const appSourceFingerprint = () => {
  const listed = git("-c", "core.quotepath=off", "ls-files", "-co", "--exclude-standard", "--", ...APP_SOURCES);
  const hash = createHash("sha256");
  for (const file of [...new Set(listed.split("\n"))].filter((name) => existsSync(join(ROOT, name))).sort()) {
    const content = readFileSync(join(ROOT, file), "latin1").replace(/\r\n/g, "\n");
    hash.update(`${file}\0${content.length}\0`).update(content, "latin1");
  }
  return hash.digest("hex").slice(0, 16);
};

/** 기기에 깔린 앱의 지문. pnpm build 로 만들지 않은 앱이면 undefined */
export const installedAppFingerprint = () => {
  const { stdout } = spawnSync("adb", ["shell", "dumpsys", "package", APP], { encoding: "utf8", timeout: 15_000 });
  return /versionName=\S+-([0-9a-f]{16})\s/.exec(stdout ?? "")?.[1];
};

/** 번호를 열 때 서버에 알리는 것. 알 수 없는 것은 비운다 */
export const runCode = () => ({
  testCommit: git("rev-parse", "HEAD"),
  testDirty: git("status", "--porcelain", "--", ...TEST_SOURCES) !== "",
  target: installedAppFingerprint(),
});
