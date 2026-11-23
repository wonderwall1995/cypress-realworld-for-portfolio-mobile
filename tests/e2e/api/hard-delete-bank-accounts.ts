import { expect } from "expect-webdriverio";
import { step } from "../fixture/step";
import type { Person } from "./person";

/**
 * API 도구: 이 사람의 은행 계좌를 DB에서 완전히 지운다 (하드 삭제).
 * 앱의 삭제는 숨기기(visible을 끔)라서 행이 남는다. 이 도구는 숨겨진 행까지 모두 지운다.
 * 시연용 API(운영 서버에서도 열려 있다)를 쓴다. 로그인이 필요하고 자기 계좌만 다룬다.
 *   - GET    /api/demo/bankaccounts/count : 이 사용자의 행 수 (숨겨진 행 포함)
 *   - DELETE /api/demo/bankaccounts       : 이 사용자의 행을 모두 지운다
 * 확인: 지운 개수가 그 행 수(숨겨진 행 포함)와 같고, 지운 뒤에는 0행이다. 처음부터 0행이면 아무것도 하지 않는다 (afterEach 에서 부르기 때문이다).
 */
export async function hardDeleteBankAccountsWithApi(who: Person) {
  return step("api", "hardDeleteBankAccountsWithApi", async () => {
    const rows = async () => {
      const response = await who.api.get("/api/demo/bankaccounts/count");
      expect(response.ok()).toBeTruthy();
      const body = await response.json();
      return body.total as number;
    };

    const before = await rows();
    if (before === 0) return; // 치울 것이 없다 (계좌를 만들기 전에 멈춘 시험)

    const response = await who.api.delete("/api/demo/bankaccounts");
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.deleted).toBe(before);

    expect(await rows()).toBe(0);
  });
}
