// 릴리스의 세 단계. GitHub Actions(.github/workflows/release.yml)가 부른다. 설치 없이 Node 24로 바로 돈다 (node tools/release.mts ...).
//   decide    main 의 package.json 버전이 마지막 릴리스보다 높은가
//   build     APK를 만들고 확인한다 (내 PC에서는 pnpm release:build. 아무것도 올리지 않는다)
//   publish   시험판(pre-release)으로 공개한다. GitHub Actions 안에서만 된다
// 릴리스의 버전은 루트 package.json 의 version 이다. 사람이 올린다. (번호 서버에 보내는 apps/mobile/VERSION 과는 따로다)
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { appendFileSync, copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const ROOT = join(import.meta.dirname, "..");
const APP_FOLDER = join(ROOT, "apps", "mobile");
const WINDOWS = process.platform === "win32";
// 서명 인증서의 SHA-256. 비밀이 아니다. 다른 키로 서명되면 받은 사람이 업데이트할 수 없다
const CERTIFICATE = "ab445d4d105c69fa97b82aa63b08cd3665249183549e58a6b2aefecddeb43b4f";
const FILES = [
  { abi: "arm64-v8a", name: "arm64" },
  { abi: "x86_64", name: "x86_64" },
];

function stop(message: string): never {
  console.error(`\n릴리스를 멈췄습니다: ${message}\n`);
  process.exit(1);
}
function check(ok: unknown, message: string): asserts ok {
  if (!ok) stop(message);
}
const run = (command: string, ...args: string[]) => {
  const done = spawnSync(command, args, { cwd: ROOT, encoding: "utf8", timeout: 300_000, maxBuffer: 64 * 1024 * 1024 });
  return { ok: done.status === 0, text: (done.stdout ?? "").trim(), error: (done.stderr ?? String(done.error ?? "")).trim() };
};
const git = (...args: string[]) => {
  const done = run("git", ...args);
  check(done.ok, `git ${args[0]} 을(를) 하지 못했습니다. ${done.error}`);
  return done.text;
};

// ---- 버전 ----
type Version = [number, number, number];
/** 앞.가운데.뒤. 모양이 틀리면 undefined */
export const parseVersion = (text: unknown): Version | undefined => {
  const found = /^(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})$/.exec(typeof text === "string" ? text : "");
  return found ? [Number(found[1]), Number(found[2]), Number(found[3])] : undefined;
};
/** 안쪽 번호. 커져야 덮어 설치된다 (0.100.0 -> 100000). 버전이 높으면 이것도 반드시 크다 */
export const buildNumberOf = ([major, middle, last]: Version) => major * 1_000_000 + middle * 1_000 + last;
/** 이미 릴리스한 버전 가운데 가장 높은 것. 다른 모양의 태그는 보지 않는다. 없으면 0.0.0 */
export const newestRelease = (tags: string): Version =>
  tags
    .split("\n")
    .map((line) => parseVersion(/refs\/tags\/app-v(\S+)$/.exec(line.trim())?.[1]))
    .filter((version) => version !== undefined)
    .reduce<Version>((best, one) => (buildNumberOf(one) > buildNumberOf(best) ? one : best), [0, 0, 0]);

const written = (): string => JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version;
const checkedVersion = () => {
  const text = written();
  const version = parseVersion(text);
  check(version, `package.json 의 version(${text ?? "없음"})은 0.100.0 처럼 세 자리 숫자여야 합니다 (자리마다 999까지).`);
  return { text, version };
};
const outFolder = (text: string) => join(APP_FOLDER, "build", `release-${text}`);
const fileNames = (text: string) => [...FILES.map(({ name }) => `rwa-mobile-${text}-${name}.apk`), "SHA256SUMS.txt"];

// ---- decide ----
const decide = () => {
  const { text, version } = checkedVersion();
  const newest = newestRelease(git("ls-remote", "--tags", "origin", "refs/tags/app-v*"));
  const release = buildNumberOf(version) > buildNumberOf(newest);
  console.log(`package.json ${text}, 마지막 릴리스 ${newest.join(".")}: ${release ? "릴리스합니다" : "버전이 오르지 않아 릴리스하지 않습니다"}`);
  if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `release=${release}\nversion=${text}\n`);
};

// ---- build ----
const flutter = (...args: string[]) => {
  console.log(`\n> flutter ${args.join(" ")}`);
  // Windows의 flutter 는 bat 파일이라 셸로 부른다
  return spawnSync(WINDOWS ? `flutter ${args.join(" ")}` : "flutter", WINDOWS ? [] : args, { cwd: APP_FOLDER, stdio: "inherit", shell: WINDOWS }).status === 0;
};
const apiAddress = () => {
  const file = join(ROOT, ".env.release"); // 내 PC에서만. 커밋하지 않는다
  const text = process.env.API_BASE_URL ?? (existsSync(file) ? /^API_BASE_URL=(\S+)\s*$/m.exec(readFileSync(file, "utf8"))?.[1] : undefined);
  check(text && /^https:\/\/[\w.:-]+\/api$/.test(text), "API_BASE_URL 은 https:// 로 시작하고 /api 로 끝나야 합니다 (GitHub의 변수, 내 PC에서는 .env.release).");
  return text;
};
const androidTools = () => {
  const sdk = process.env.ANDROID_HOME || (WINDOWS ? join(process.env.LOCALAPPDATA ?? "", "Android", "Sdk") : join(homedir(), "Android", "Sdk"));
  const folder = join(sdk, "build-tools");
  const newest = existsSync(folder)
    ? readdirSync(folder).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })).at(-1)
    : undefined;
  check(newest, `Android SDK의 build-tools 를 찾지 못했습니다 (${folder}).`);
  const studio = "C:\\Program Files\\Android\\Android Studio\\jbr\\bin\\java.exe";
  const home = process.env.JAVA_HOME ? join(process.env.JAVA_HOME, "bin", WINDOWS ? "java.exe" : "java") : "";
  return {
    aapt: join(folder, newest, WINDOWS ? "aapt.exe" : "aapt"),
    apksigner: join(folder, newest, "lib", "apksigner.jar"),
    java: [home, WINDOWS ? studio : ""].find((path) => path && existsSync(path)) ?? "java",
  };
};

const build = () => {
  const { text, version } = checkedVersion();
  check(buildNumberOf(version) > 0, "package.json 의 version 이 0.0.0 입니다. 먼저 올리세요.");
  const api = apiAddress();
  const keyFile = join(APP_FOLDER, "android", "key.properties");
  check(existsSync(keyFile), "apps/mobile/android/key.properties 가 없습니다. 이대로 만들면 디버그 키로 서명됩니다.");
  const passwords = [...readFileSync(keyFile, "utf8").matchAll(/^(?:storePassword|keyPassword)=(.+?)\r?$/gm)].map((found) => found[1]);
  check(passwords.length === 2, "key.properties 의 비밀번호 칸이 비어 있습니다.");
  const { aapt, apksigner, java } = androidTools();

  const built = join(APP_FOLDER, "build", "app", "outputs", "flutter-apk");
  for (const { abi } of FILES) rmSync(join(built, `app-${abi}-release.apk`), { force: true }); // 예전 파일을 올리지 않게
  check(
    flutter("build", "apk", "--release", "--split-per-abi", `--build-name=${text}`, `--build-number=${buildNumberOf(version)}`, `--dart-define=API_BASE_URL=${api}`),
    "APK를 만들지 못했습니다."
  );

  const out = outFolder(text);
  rmSync(out, { recursive: true, force: true });
  const inside = join(out, "inside");
  const sums: string[] = [];
  for (const { abi, name } of FILES) {
    const file = `rwa-mobile-${text}-${name}.apk`;
    const path = join(out, file);
    mkdirSync(inside, { recursive: true });
    copyFileSync(join(built, `app-${abi}-release.apk`), path);
    const signature = run(java, "-jar", apksigner, "verify", "--print-certs", path);
    check(signature.ok && signature.text.includes(CERTIFICATE), `${file} 이 내 서명 키로 서명되지 않았습니다.`);
    const badge = run(aapt, "dump", "badging", path).text;
    check(badge.includes(`versionName='${text}'`), `${file} 의 버전이 다릅니다.`);
    check(badge.includes(`native-code: '${abi}'`), `${file} 의 기기 종류가 다릅니다.`);
    check(!badge.includes("application-debuggable"), `${file} 이 release 앱이 아닙니다.`);
    // APK는 zip 이다. 풀어서 안을 본다
    const unpacked = WINDOWS
      ? run(join(process.env.SystemRoot ?? "C:\\Windows", "System32", "tar.exe"), "-xf", path, "-C", inside)
      : run("unzip", "-q", path, "-d", inside);
    check(unpacked.ok, `${file} 을 풀지 못했습니다.`);
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
    .replaceAll("{{version}}", text)
    .replaceAll("{{commit}}", git("rev-parse", "--short=7", "HEAD"))
    .replaceAll("{{certificate}}", CERTIFICATE);
  check(!notes.includes("{{"), "릴리스 글에 채우지 못한 칸이 있습니다.");
  writeFileSync(join(out, "release-notes.md"), notes);
  console.log(`\n확인함: 서명, 버전, 서버 주소, 비밀 값 없음\n${out}\n${sums.join("\n")}`);
};

// ---- publish ----
const publish = () => {
  check(process.env.GITHUB_ACTIONS === "true", "공개는 GitHub Actions 안에서만 합니다.");
  const { text } = checkedVersion();
  const commit = git("rev-parse", "HEAD");
  check(commit === process.env.GITHUB_SHA, "받은 코드가 이 실행의 커밋이 아닙니다.");
  const out = outFolder(text);
  const files = fileNames(text).map((name) => join(out, name));
  for (const file of [...files, join(out, "release-notes.md")]) check(existsSync(file), `올릴 파일이 없습니다: ${file}`);
  // 만든 작업에서 이 작업으로 넘어오는 동안 바뀌지 않았는지
  for (const line of readFileSync(join(out, "SHA256SUMS.txt"), "utf8").trim().split("\n")) {
    const [sum, name] = line.split("  ");
    check(createHash("sha256").update(readFileSync(join(out, name))).digest("hex") === sum, `${name} 이 만든 것과 다릅니다.`);
  }
  // 파일을 다 올린 뒤에 공개된다 (gh 가 초안으로 만들고 마지막에 연다)
  const made = run("gh", "release", "create", `app-v${text}`, ...files, "--prerelease", "--target", commit, "--title", `RWA Mobile ${text} (시험판)`, "--notes-file", join(out, "release-notes.md"));
  check(made.ok, `공개하지 못했습니다. GitHub의 Releases에 남은 초안이 있으면 지우고 다시 돌리세요.\n${made.error}`);
  console.log(`공개했습니다: ${made.text}`);
};

// 시험이 부품만 가져갈 때는 아무것도 하지 않는다
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const command = { decide, build, publish }[process.argv[2] ?? ""];
  if (!command) stop("node tools/release.mts decide | build | publish");
  command();
}
