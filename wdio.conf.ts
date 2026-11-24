import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { browser } from "@wdio/globals";
import { closeDb } from "./tests/e2e/db/client";
import { keepOutcome, outcomeOf, sendOutcome } from "./tests/e2e/fixture/run-results";
import { StepRecord, takeStepRecords } from "./tests/e2e/fixture/step";

const E2E = join(__dirname, "tests", "e2e");

// 커밋하지 않는 값 (E2E_API_URL, E2E_DATABASE_URL). 루트의 .env 는 앱 빌드에 넘기는 값만 두는 곳이라 따로 둔다
if (existsSync(join(E2E, ".env"))) process.loadEnvFile(join(E2E, ".env"));

// 이 PC의 자리. 환경 값이 있으면 그것을 쓴다
process.env.ANDROID_HOME ??= join(process.env.LOCALAPPDATA ?? "", "Android", "Sdk");
process.env.JAVA_HOME ??= "C:/Program Files/Android/Android Studio/jbr";

const PKG = "io.github.wonderwall1995.cypress_realworld_for_personal_portfolio_mobile";
const LOGS = join(E2E, "logs"); // 실패했을 때의 화면. 커밋하지 않는다

const takeSteps = () => {
  const steps = takeStepRecords();
  for (const item of steps) {
    console.log(
      `${"  ".repeat(item.depth)}[${item.kind}] ${item.name} ${item.status} ${item.durationMs}ms`
    );
  }
  return steps;
};

// 정식 실행(test-run.ts)의 기록. 시험이 끝나도 정리(afterEach)의 도구까지 모은 뒤에 보낸다
let startedAt = 0;
let ended: { test: TestInfo; result: TestEnd; steps: StepRecord[] } | undefined;
interface TestInfo {
  title: string;
  file: string;
}
interface TestEnd {
  passed: boolean;
  error?: { message?: string };
  duration: number;
}

// 파일에 먼저 적고 보낸다. 보내지 못해도 시험은 계속한다 (test-run.ts 가 끝에 한 번 더 보낸다). 보내는 것이 살아 있다는 신호도 된다
const recordEnded = async () => {
  if (!ended) return;
  const { test, result, steps } = ended;
  ended = undefined;
  const { TEST_RUN_NO, TEST_RUN_SERVER, TEST_RUN_RESULTS_FILE } = process.env;
  if (!TEST_RUN_NO || !TEST_RUN_SERVER || !TEST_RUN_RESULTS_FILE) return; // 번호 없는 실행
  const outcome = outcomeOf(test, { ...result, startedAt, durationMs: result.duration }, steps);
  if (!outcome) return;
  keepOutcome(TEST_RUN_RESULTS_FILE, outcome);
  await sendOutcome(TEST_RUN_SERVER, TEST_RUN_NO, outcome);
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

  beforeTest: () => {
    startedAt = Date.now();
  },

  afterTest: async (test: TestInfo, _context: unknown, result: TestEnd) => {
    ended = { test, result, steps: takeSteps() };
    if (result.passed) return;
    mkdirSync(LOGS, { recursive: true });
    const name = join(LOGS, `${Date.now()}-${test.title.slice(0, 20).replace(/[^0-9A-Za-z가-힣]/g, "_")}`);
    await browser.saveScreenshot(`${name}.png`);
    writeFileSync(`${name}.xml`, await browser.getPageSource());
  },

  // 정리(afterEach)에서 부른 도구도 그 시험의 것이다
  afterHook: async () => {
    const steps = takeSteps();
    if (!ended) return;
    ended.steps.push(...steps);
    await recordEnded();
  },

  after: async () => {
    await recordEnded(); // 정리가 없는 시험
    await closeDb();
  },
};
