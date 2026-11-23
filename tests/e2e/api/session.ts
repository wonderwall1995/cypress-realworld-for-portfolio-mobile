/**
 * 한 사람의 API 로그인 하나. 앱(화면)의 로그인과 별개다.
 * 웹의 page.request 와 같은 이름(get, post, patch, delete / status(), ok(), json())이라 웹의 api/ 도구를 거의 그대로 옮길 수 있다.
 * Node 24 에 들어 있는 fetch 만 쓴다 (새 패키지 없음).
 */
export class ApiAnswer {
  private readonly code: number;
  private readonly text: string;
  constructor(code: number, text: string) {
    this.code = code;
    this.text = text;
  }
  status() {
    return this.code;
  }
  ok() {
    return this.code >= 200 && this.code < 300;
  }
  json() {
    return JSON.parse(this.text);
  }
}

export class ApiSession {
  private cookies = new Map<string, string>();
  private readonly baseUrl: string;
  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  get = (path: string) => this.send("GET", path);
  delete = (path: string) => this.send("DELETE", path);
  post = (path: string, body: { data?: unknown } = {}) => this.send("POST", path, body.data);
  patch = (path: string, body: { data?: unknown } = {}) => this.send("PATCH", path, body.data);

  private async send(method: string, path: string, data?: unknown) {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      redirect: "manual", // 로그아웃은 "/"로 보내는 답을 준다. 따라가지 않는다
      signal: AbortSignal.timeout(15_000),
      headers: {
        ...(data === undefined ? {} : { "content-type": "application/json" }),
        ...(this.cookies.size > 0
          ? { cookie: [...this.cookies].map(([name, value]) => `${name}=${value}`).join("; ") }
          : {}),
      },
      body: data === undefined ? undefined : JSON.stringify(data),
    });
    for (const line of response.headers.getSetCookie()) {
      const [name, ...value] = line.split(";")[0].split("=");
      this.cookies.set(name, value.join("="));
    }
    return new ApiAnswer(response.status, await response.text());
  }
}

/** 테스트(PC)가 보는 서버. 앱이 보는 서버(API_BASE_URL)와 같은 서버여야 한다 */
export const apiUrl = () => process.env.E2E_API_URL ?? "http://127.0.0.1:7202";

/** 새 API 로그인 자리를 만든다 (아직 로그인하지 않음). 내 PC가 아닌 서버는 E2E_ALLOW_REMOTE=1 일 때만 연다 */
export const newApiSession = () => {
  const { hostname } = new URL(apiUrl());
  const mine = ["127.0.0.1", "localhost", "[::1]"].includes(hostname);
  if (!mine && process.env.E2E_ALLOW_REMOTE !== "1") {
    throw new Error("내 PC가 아닌 서버입니다. 정말 쓰려면 E2E_ALLOW_REMOTE=1 을 주세요.");
  }
  return new ApiSession(apiUrl());
};
