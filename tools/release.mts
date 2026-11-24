// 내 PC에서 release APK를 만들고 GitHub에 초안으로 올린다. 공개(Publish)는 하지 않는다: 사람이 GitHub 화면에서 누른다.
//   pnpm release:build   만들고 확인만 한다 (아무것도 올리지 않는다)
//   pnpm release:draft   만들고 확인한 뒤, 초안(draft) + 시험판(pre-release)으로 올린다
//   --try                아직 main 이 아닌 코드로 만들어 본다 (release:build 에서만)
// 서명 키와 비밀번호는 이 PC를 떠나지 않는다. 버전은 apps/mobile/VERSION 하나를 올리면 된다.
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { appSourceFingerprint, ROOT, writtenVersion } from "../tests/e2e/run-code";

const APP_FOLDER = join(ROOT, "apps", "mobile");
const BUILT = join(APP_FOLDER, "build", "app", "outputs", "flutter-apk");
const ENV_FILE = join(ROOT, ".env.release"); // API_BASE_URL=https://.../api 커밋하지 않는다
const KEY_FILE = join(APP_FOLDER, "android", "key.properties");
// 서명 인증서의 SHA-256. 비밀이 아니다. 다른 키로 서명되면 받은 사람이 업데이트할 수 없다
const CERTIFICATE = "ab445d4d105c69fa97b82aa63b08cd3665249183549e58a6b2aefecddeb43b4f";
const FILES = [
  { abi: "arm64-v8a", name: "arm64" },
  { abi: "x86_64", name: "x86_64" },
];

const draft = process.argv.includes("--draft");
const trying = process.argv.includes("--try");

function stop(message: string): never {
  console.error(`\n릴리스를 멈췄습니다: ${message}\n`);
  process.exit(1);
}
function check(ok: unknown, message: string): asserts ok {
  if (!ok) stop(message);
}
const read = (command: string, ...args: string[]) => {
  const run = spawnSync(command, args, { cwd: ROOT, encoding: "utf8", timeout: 120_000, maxBuffer: 64 * 1024 * 1024 });
  return { ok: run.status === 0, text: (run.stdout ?? "").trim(), error: (run.stderr ?? "").trim() };
};
const git = (...args: string[]) => {
  const run = read("git", ...args);
  check(run.ok, `git ${args[0]} 을(를) 하지 못했습니다. ${run.error}`);
  return run.text;
};
const changes = () => git("status", "--porcelain", "--untracked-files=no");
// Windows의 flutter 는 bat 파일이라 셸로 부른다
const flutter = (args: string) => {
  console.log(`\n> flutter ${args}`);
  return spawnSync(`flutter ${args}`, { cwd: APP_FOLDER, stdio: "inherit", shell: true }).status === 0;
};

// 1) 무엇을 만드는가
check(!(draft && trying), "--try 로 만든 것은 올릴 수 없습니다.");
const version = writtenVersion() ?? stop("apps/mobile/VERSION 에 버전이 없거나 모양이 틀립니다 (예: 0.100).");
const tag = `app-v${version}`;
const commit = git("rev-parse", "HEAD");
const fingerprint = appSourceFingerprint();
// 안쪽 번호는 커져야 덮어 설치된다. 버전에서 계산하므로 VERSION 만 올리면 된다 (0.100 -> 100, 1.5 -> 1000005)
const [major, minor] = version.split(".").map(Number);
const buildNumber = major * 1_000_000 + minor;
check(buildNumber > 0 && buildNumber < 2_000_000_000, "VERSION 이 너무 작거나 큽니다.");

if (!trying) {
  git("fetch", "-q", "--tags", "origin");
  check(git("branch", "--show-current") === "main", "main 브랜치에서만 만듭니다. 다른 브랜치에서 만들어 보려면 pnpm release:build --try");
  check(commit === git("rev-parse", "refs/remotes/origin/main"), "내 main 과 GitHub의 main 이 다릅니다. pull 이나 push 를 먼저 하세요.");
  check(changes() === "", "커밋하지 않은 변경이 있습니다.");
  check(git("ls-remote", "--tags", "origin", `refs/tags/${tag}`) === "", `${tag} 는 이미 공개한 버전입니다. apps/mobile/VERSION 을 올리세요.`);
}

// 2) 준비물
check(existsSync(ENV_FILE), ".env.release 가 없습니다. 저장소 맨 위에 만들고 API_BASE_URL=https://.../api 를 적으세요.");
const api = /^API_BASE_URL=(\S+)\s*$/m.exec(readFileSync(ENV_FILE, "utf8"))?.[1] ?? "";
check(/^https:\/\/\S+\/api$/.test(api), ".env.release 의 API_BASE_URL 은 https:// 로 시작하고 /api 로 끝나야 합니다.");
check(existsSync(KEY_FILE), "apps/mobile/android/key.properties 가 없습니다. 이대로 만들면 디버그 키로 서명됩니다.");
const passwords = [...readFileSync(KEY_FILE, "utf8").matchAll(/^(?:storePassword|keyPassword)=(.+?)\r?$/gm)].map((found) => found[1]);
check(passwords.length === 2, "key.properties 의 비밀번호 칸이 비어 있습니다.");
const toolsFolder = join(process.env.ANDROID_HOME || join(process.env.LOCALAPPDATA ?? "", "Android", "Sdk"), "build-tools");
check(existsSync(toolsFolder), `Android SDK의 build-tools 를 찾지 못했습니다 (${toolsFolder}).`);
const newest = readdirSync(toolsFolder).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })).at(-1);
check(newest, "Android SDK의 build-tools 가 비어 있습니다.");
const tools = join(toolsFolder, newest);
const java = [
  join(process.env.JAVA_HOME ?? "", "bin", "java.exe"),
  "C:\\Program Files\\Android\\Android Studio\\jbr\\bin\\java.exe",
].find((path) => existsSync(path));
check(java, "Java를 찾지 못했습니다. Android Studio를 설치하거나 JAVA_HOME 을 정하세요.");
const answer = await fetch(`${api}/checkAuth`, { signal: AbortSignal.timeout(15_000) })
  .then((got) => got.status)
  .catch(() => 0);
check(answer === 401, `배포 서버가 답하지 않습니다 (${answer === 0 ? "연결 안 됨" : `응답 ${answer}`}).`);
if (draft) {
  check(read("gh", "--version").ok, "gh 가 없습니다. winget install GitHub.cli 로 설치하고 CMD 창을 새로 여세요.");
  check(read("gh", "auth", "status", "--hostname", "github.com").ok, "gh 에 로그인하지 않았습니다. gh auth login 을 하세요.");
  // 초안은 태그가 없어서 위의 태그 검사에 걸리지 않는다
  const releases = read("gh", "release", "list", "--limit", "100", "--json", "tagName", "--jq", ".[].tagName");
  check(releases.ok, `GitHub의 릴리스 목록을 읽지 못했습니다. ${releases.error}`);
  check(!releases.text.split(/\r?\n/).includes(tag), `${tag} 릴리스(또는 초안)가 이미 있습니다. GitHub에서 초안을 지우거나 VERSION 을 올리세요.`);
}
console.log(`릴리스 ${tag}: 커밋 ${commit.slice(0, 7)}, 지문 ${fingerprint}, 안쪽 번호 ${buildNumber}${trying ? " (만들어 보기)" : ""}`);

// 3) 검사하고 만든다
check(flutter("analyze"), "flutter analyze 에서 문제가 나왔습니다.");
check(flutter("test"), "앱의 테스트가 실패했습니다.");
for (const { abi } of FILES) rmSync(join(BUILT, `app-${abi}-release.apk`), { force: true }); // 예전 파일을 올리지 않게
check(
  flutter(
    `build apk --release --split-per-abi --build-name=${version}-${fingerprint} --build-number=${buildNumber} --dart-define-from-file=../../.env.release`
  ),
  "APK를 만들지 못했습니다."
);
check(appSourceFingerprint() === fingerprint && git("rev-parse", "HEAD") === commit, "만드는 동안 소스가 바뀌었습니다. 다시 하세요.");
if (!trying) check(changes() === "", "만드는 동안 커밋하지 않은 변경이 생겼습니다.");

// 4) 만든 파일을 확인한다
const out = join(APP_FOLDER, "build", `release-${version}${trying ? "-try" : ""}`);
rmSync(out, { recursive: true, force: true });
const inside = join(out, "inside");
const sums: string[] = [];
for (const { abi, name } of FILES) {
  const file = `rwa-mobile-${version}-${name}.apk`;
  const path = join(out, file);
  mkdirSync(inside, { recursive: true });
  copyFileSync(join(BUILT, `app-${abi}-release.apk`), path);
  const signature = read(java, "-jar", join(tools, "lib", "apksigner.jar"), "verify", "--print-certs", path);
  check(signature.ok && signature.text.includes(CERTIFICATE), `${file} 이 내 서명 키로 서명되지 않았습니다.`);
  const badge = read(join(tools, "aapt.exe"), "dump", "badging", path).text;
  check(badge.includes(`versionName='${version}-${fingerprint}'`), `${file} 의 버전이 다릅니다.`);
  check(badge.includes(`native-code: '${abi}'`), `${file} 의 기기 종류가 다릅니다.`);
  check(!badge.includes("application-debuggable"), `${file} 이 release 앱이 아닙니다.`);
  // APK는 zip 이다. 풀어서 안을 본다
  const tar = join(process.env.SystemRoot ?? "C:\\Windows", "System32", "tar.exe");
  check(read(tar, "-xf", path, "-C", inside).ok, `${file} 을 풀지 못했습니다.`);
  const contents = readdirSync(inside, { recursive: true, withFileTypes: true }).filter((entry) => entry.isFile());
  const bytes = contents.map((entry) => readFileSync(join(entry.parentPath, entry.name)));
  check(bytes.some((content) => content.includes(api)), `${file} 에 배포 서버 주소가 없습니다.`);
  check(!bytes.some((content) => content.includes("10.0.2.2")), `${file} 에 개발용 주소가 있습니다.`);
  check(!bytes.some((content) => passwords.some((password) => content.includes(password))), `${file} 에 서명 비밀번호가 있습니다.`);
  check(!contents.some((entry) => /\.(jks|keystore)$|^key\.properties$|^\.env/.test(entry.name)), `${file} 에 비밀 파일이 있습니다.`);
  rmSync(inside, { recursive: true, force: true });
  sums.push(`${createHash("sha256").update(readFileSync(path)).digest("hex")}  ${file}`);
}
writeFileSync(join(out, "SHA256SUMS.txt"), `${sums.join("\n")}\n`);
const notes = readFileSync(join(ROOT, "docs", "release", "release-notes.template.md"), "utf8")
  .replace(/\r\n/g, "\n")
  .replaceAll("{{version}}", version)
  .replaceAll("{{commit}}", commit.slice(0, 7))
  .replaceAll("{{certificate}}", CERTIFICATE);
check(!notes.includes("{{"), "릴리스 글에 채우지 못한 칸이 있습니다.");
const notesFile = join(out, "release-notes.md");
writeFileSync(notesFile, notes);
console.log(`\n확인함: 서명, 버전, 서버 주소, 비밀 값 없음\n${out}\n${sums.join("\n")}`);

// 5) 초안으로 올린다
if (draft) {
  const files = [...FILES.map(({ name }) => `rwa-mobile-${version}-${name}.apk`), "SHA256SUMS.txt"].map((file) => join(out, file));
  console.log("\nGitHub에 초안으로 올립니다...");
  const made = spawnSync(
    "gh",
    ["release", "create", tag, ...files, "--draft", "--prerelease", "--target", commit, "--title", `RWA Mobile ${version} (시험판)`, "--notes-file", notesFile],
    { cwd: ROOT, encoding: "utf8", timeout: 600_000 }
  );
  if (made.status !== 0) stop(`초안을 올리지 못했습니다. GitHub의 Releases에 반쯤 올라간 초안이 있는지 보세요.\n${made.stderr ?? made.error}`);
  console.log(`초안을 만들었습니다: ${made.stdout.trim()}`);
  console.log("아직 공개되지 않았습니다. 폰에서 확인한 뒤 GitHub 화면에서 Publish release 를 누르세요.");
} else {
  console.log("\n아무것도 올리지 않았습니다. 올리려면 pnpm release:draft");
}
