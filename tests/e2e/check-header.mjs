// 모든 spec의 공통 머리말이 원본(testcode.template.ts)과 같은지 본다. 실행: node tests/e2e/check-header.mjs
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const END = "공통 머리말 끝 =====\n */\n";
const headOf = (file) => {
  const text = readFileSync(join(import.meta.dirname, file), "utf8").replaceAll("\r\n", "\n");
  return text.slice(0, text.indexOf(END) + END.length);
};
const original = headOf("testcode.template.ts");
const different = readdirSync(import.meta.dirname).filter((file) => /^\d{3}-.*\.spec\.ts$/.test(file) && headOf(file) !== original);
console.log(different.length === 0 ? "ok" : `원본과 다른 머리말: ${different.join(", ")}`);
process.exitCode = different.length === 0 ? 0 : 1;
