import { RandomUser } from "../fixture/random-user";
import type { ApiSession } from "./session";

/**
 * 시험에 나오는 사람 하나: 로그인에 쓰는 값(id 포함)과 그 사람의 API 로그인.
 * api 는 화면(앱)의 로그인과 별개다. 사람마다 하나씩 가지므로, 다른 사람의 일을 하려고 로그인을 바꾸지 않는다.
 */
export interface Person {
  user: RandomUser & { id: string };
  api: ApiSession;
}
