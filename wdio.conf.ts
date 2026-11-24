import { appendFileSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { browser } from "@wdio/globals";
import { closeDb } from "./tests/e2e/db/client";
import { takeStepRecords } from "./tests/e2e/fixture/step";

const E2E = join(__dirname, "tests", "e2e");

// 커밋하지 않는 값 (E2E_API_URL, E2E_DATABASE_URL). 루트의 .env 에 두지 않는다: 그 파일은 앱 빌드에 통째로 들어간다
if (existsSync(join(E2E, ".env"))) process.loadEnvFile(join(E2E, ".env"));

// 이 PC의 자리. 환경 값이 있으면 그것을 쓴다
process.env.ANDROID_HOME ??= join(process.env.LOCALAPPDATA ?? "", "Android", "Sdk");
process.env.JAVA_HOME ??= "C:/Program Files/Android/Android Studio/jbr";

const PKG = "io.github.wonderwall1995.cypress_realworld_for_personal_portfolio_mobile";
const LOGS = join(E2E, "logs"); // 실패했을 때의 화면. 커밋하지 않는다

const printSteps = () => {
  for (const item of takeStepRecords()) {
    console.log(
      `${"  ".repeat(item.depth)}[${item.kind}] ${item.name} ${item.status} ${item.durationMs}ms`
    );
  }
};

// 정식 실행(test-run.ts)이면 시험이 하나 끝날 때마다 번호 서버에 살아 있다고 알린다. 알리지 못해도 시험은 계속한다
const tellAlive = async (title: string) => {
  const { TEST_RUN_NO, TEST_RUN_SERVER, TEST_RUN_SECRET, TEST_RUN_DONE_FILE } = process.env;
  if (!TEST_RUN_NO || !TEST_RUN_DONE_FILE) return;
  appendFileSync(TEST_RUN_DONE_FILE, `${title}\n`);
  await fetch(`${TEST_RUN_SERVER}/api/testRuns/${TEST_RUN_NO}/signal`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${TEST_RUN_SECRET ?? ""}` },
    body: JSON.stringify({ platform: "app" }),
    signal: AbortSignal.timeout(10_000),
  }).catch(() => undefined);
};

export const config = {
  runner: "local",
  specs: ["./tests/e2e/[0-9][0-9][0-9]-*.spec.ts"], // 번호로 시작하는 파일만 시험이다
  maxInstances: 1, // 에뮬레이터가 하나라서 차례대로 돈다
  logLevel: "warn",
  waitforTimeout: 15_000,
  framework: "mocha",
  mochaOpts: { timeout: 8 * 60_000 },
  reporters: ["spec"],
  services: [["appium", { command: "appium", args: { port: 4733 } }]],
  port: 4733,
  capabilities: [
    {
      platformName: "Android",
      "appium:automationName": "UiAutomator2",
      "appium:appPackage": PKG,
      "appium:appActivity": ".MainActivity",
      "appium:noReset": true, // 앱의 데이터는 openApp 도구가 테스트마다 비운다
      "appium:forceAppLaunch": true,
      "appium:disableIdLocatorAutocompletion": true,
      "appium:newCommandTimeout": 120,
    },
  ],

  afterTest: async (
    test: { title: string },
    _context: unknown,
    result: { passed: boolean }
  ) => {
    printSteps();
    await tellAlive(test.title);
    if (result.passed) return;
    mkdirSync(LOGS, { recursive: true });
    const name = join(LOGS, `${Date.now()}-${test.title.slice(0, 20).replace(/[^0-9A-Za-z가-힣]/g, "_")}`);
    await browser.saveScreenshot(`${name}.png`);
    writeFileSync(`${name}.xml`, await browser.getPageSource());
  },

  // 정리(afterEach)에서 부른 도구. 다음 테스트의 기록에 섞이지 않게 여기서 꺼낸다
  afterHook: () => printSteps(),

  after: () => closeDb(),
};
