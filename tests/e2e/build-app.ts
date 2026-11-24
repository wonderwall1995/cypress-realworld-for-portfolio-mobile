// 앱(debug APK)을 만든다 (pnpm build). 사람이 적은 버전과 소스의 지문을 버전 이름에 넣어, 나중에 기기에 깔린 앱이 어느 것인지 알 수 있게 한다.
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { appSourceFingerprint, ROOT, writtenVersion } from "./run-code";

const APP_FOLDER = join(ROOT, "apps", "mobile");
const version = writtenVersion();
if (!version) throw new Error("apps/mobile/VERSION 에 버전이 없거나 모양이 틀립니다 (예: 0.100).");

const before = appSourceFingerprint();
const buildName = `${version}-${before}`;
console.log(`앱을 만듭니다: ${buildName}`);
// Windows의 flutter 는 bat 파일이라 셸로 부른다 (buildName 은 숫자, 점, 16진수뿐이다)
const { status } = spawnSync(`flutter build apk --debug --dart-define-from-file=../../.env --build-name=${buildName}`, {
  cwd: APP_FOLDER,
  stdio: "inherit",
  shell: true,
});
// 만드는 동안 소스가 바뀌면 지문이 틀린 앱이 된다
if (status === 0 && appSourceFingerprint() !== before) {
  console.error("앱을 만드는 동안 소스가 바뀌었습니다. pnpm build 를 다시 하세요.");
  process.exitCode = 1;
} else process.exitCode = status ?? 1;
