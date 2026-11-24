import { expect } from "expect-webdriverio";
import { RandomUser } from "../fixture/random-user";
import { step } from "../fixture/step";
import type { Person } from "./person";
import { newApiSession } from "./session";

/**
 * API 도구: 이미 있는 계정으로 API 로그인을 새로 열고, 그 사람을 돌려준다 (POST /api/login).
 * 화면의 로그인은 바뀌지 않는다. 화면에서 가입한 사람을 API로 볼 때도 쓴다.
 * 동작이 됐는지만 확인한다: 로그인이 되지 않으면 이 도구를 부른 줄에서 테스트가 멈춘다.
 */
export async function loginWithApi(user: RandomUser): Promise<Person> {
  return step("api", "loginWithApi", async () => {
    const api = newApiSession();
    const response = await api.post("/api/login", {
      data: { username: user.username, password: user.password },
    });
    expect(response.ok()).toBeTruthy();
    const me = await api.get("/api/checkAuth");
    expect(me.ok()).toBeTruthy();
    const id: string = (await me.json()).user.id;
    return { user: { ...user, id }, api };
  });
}
