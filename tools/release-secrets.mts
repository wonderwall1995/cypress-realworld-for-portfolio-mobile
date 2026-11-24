// 한 번만 (pnpm release:secrets): GitHub에 release 환경을 만들고 서명 키, 비밀번호, 서버 주소를 넣는다. 사람이 돌린다.
// 값은 화면에 찍지 않고, 명령의 인자가 아니라 표준 입력으로 gh 에 넘긴다. GitHub에 넣은 비밀 값은 다시 읽을 수 없다.
// 환경은 main 에서만 쓸 수 있게 한다: 다른 브랜치나 남의 PR 에서는 서명 키를 읽지 못한다.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dirname, "..");
const ENVIRONMENT = "release";

function stop(message: string): never {
  console.error(`\n멈췄습니다: ${message}\n`);
  process.exit(1);
}
/** gh 의 오류 글에는 넘긴 값이 들어 있지 않다 (값은 input 으로만 간다) */
const gh = (args: string[], input?: string) => {
  const done = spawnSync("gh", args, { cwd: ROOT, input, encoding: "utf8", timeout: 60_000 });
  if (done.error) stop("gh 를 부르지 못했습니다. 설치한 뒤 CMD 창을 새로 여세요.");
  return { ok: done.status === 0, text: (done.stdout ?? "").trim(), error: (done.stderr ?? "").trim() };
};
const must = (what: string, args: string[], input?: string) => {
  const done = gh(args, input);
  if (!done.ok) stop(`${what}: ${done.error}`);
  return done.text;
};

// 1) 내 PC의 값
const keyFile = join(ROOT, "apps", "mobile", "android", "key.properties");
const envFile = join(ROOT, ".env.release");
if (!existsSync(keyFile)) stop("apps/mobile/android/key.properties 가 없습니다.");
if (!existsSync(envFile)) stop(".env.release 가 없습니다. API_BASE_URL=https://.../api 를 적으세요.");
const key = Object.fromEntries(
  readFileSync(keyFile, "utf8")
    .split(/\r?\n/)
    .filter((line) => /^\w+=/.test(line))
    .map((line) => [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)])
);
if (key.keyAlias !== "release") stop("key.properties 의 keyAlias 는 release 여야 합니다.");
if (!key.storePassword || key.storePassword !== key.keyPassword) stop("key.properties 의 비밀번호 두 칸이 비었거나 서로 다릅니다.");
if (!key.storeFile || !existsSync(key.storeFile)) stop("key.properties 의 storeFile 에 키 파일이 없습니다.");
const api = /^API_BASE_URL=(https:\/\/[\w.:-]+\/api)\s*$/m.exec(readFileSync(envFile, "utf8"))?.[1];
if (!api) stop(".env.release 의 API_BASE_URL 은 https:// 로 시작하고 /api 로 끝나야 합니다.");

// 2) 어느 저장소인가: 이 저장소의 origin 과 같아야 한다 (다른 곳에 키를 넣지 않게)
const repo = must("저장소를 읽지 못했습니다", ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]);
const origin = spawnSync("git", ["remote", "get-url", "origin"], { cwd: ROOT, encoding: "utf8" }).stdout.trim();
if (!["https://github.com/", "git@github.com:"].some((start) => origin.replace(/\.git$/, "") === start + repo)) stop(`gh 가 보는 저장소(${repo})와 origin 이 다릅니다.`);

// 3) 환경: main 에서만
must(
  "release 환경을 만들지 못했습니다",
  ["api", "-X", "PUT", `repos/${repo}/environments/${ENVIRONMENT}`, "--input", "-"],
  JSON.stringify({ deployment_branch_policy: { protected_branches: false, custom_branch_policies: true } })
);
const policies = `repos/${repo}/environments/${ENVIRONMENT}/deployment-branch-policies`;
const allowed = () => must("환경의 브랜치를 읽지 못했습니다", ["api", policies, "--jq", ".branch_policies[].name"]).split(/\r?\n/).filter(Boolean);
if (!allowed().includes("main")) must("main 만 허락하지 못했습니다", ["api", "-X", "POST", policies, "-f", "name=main", "-f", "type=branch"]);
if (allowed().join() !== "main") stop(`release 환경이 main 말고도 열려 있습니다 (${allowed().join(", ")}). GitHub Settings > Environments 에서 지우고 다시 하세요. 키는 넣지 않았습니다.`);

// 4) 값
must("서버 주소를 넣지 못했습니다", ["variable", "set", "API_BASE_URL", "--env", ENVIRONMENT, "--repo", repo], api);
must("키를 넣지 못했습니다", ["secret", "set", "ANDROID_KEYSTORE_BASE64", "--env", ENVIRONMENT, "--repo", repo], readFileSync(key.storeFile).toString("base64"));
must("비밀번호를 넣지 못했습니다", ["secret", "set", "ANDROID_KEYSTORE_PASSWORD", "--env", ENVIRONMENT, "--repo", repo], key.storePassword);
console.log(`${repo} 의 ${ENVIRONMENT} 환경에 넣었습니다 (main 에서만): 서버 주소, 서명 키, 비밀번호`);
